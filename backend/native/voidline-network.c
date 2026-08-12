#include <NetworkManager.h>
#include <gio/gio.h>
#include <glib-unix.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct {
    GMainLoop *loop;
    NMClient *client;
    NMDeviceWifi *device;
    NMAccessPoint *access_point;
    NMActiveConnection *active;
    GCancellable *cancellable;
    char *ssid;
    char *bssid;
    char *interface_name;
    char *security_hint;
    char *profile_uuid;
    char *passphrase;
    gboolean hidden;
    gboolean created_profile;
    gboolean finished;
    int exit_code;
    guint timeout_id;
    int lock_fd;
    NMDeviceStateReason last_device_reason;
    NMConnection *profile;
    gboolean persisting_profile;
} ConnectRequest;

static void secure_clear(char **value) {
    if (!value || !*value)
        return;
    volatile char *cursor = (volatile char *) *value;
    size_t length = strlen(*value);
    while (length-- > 0)
        *cursor++ = 0;
    g_free(*value);
    *value = NULL;
}

static void emit_state(const char *state) {
    g_print("state|%s\n", state);
    fflush(stdout);
}

static void emit_error(const char *code) {
    g_print("error|%s\n", code);
    fflush(stdout);
}

static gboolean ssid_matches(GBytes *candidate, const char *ssid) {
    gsize length = 0;
    const guint8 *bytes;
    size_t wanted;
    if (!candidate || !ssid)
        return FALSE;
    bytes = g_bytes_get_data(candidate, &length);
    wanted = strlen(ssid);
    return length == wanted && memcmp(bytes, ssid, length) == 0;
}

static NMDeviceWifi *find_wifi_device(NMClient *client, const char *interface_name) {
    const GPtrArray *devices = nm_client_get_devices(client);
    for (guint index = 0; devices && index < devices->len; ++index) {
        NMDevice *device = g_ptr_array_index((GPtrArray *) devices, index);
        if (!NM_IS_DEVICE_WIFI(device))
            continue;
        if (g_strcmp0(nm_device_get_iface(device), interface_name) == 0)
            return NM_DEVICE_WIFI(device);
    }
    return NULL;
}

static NMAccessPoint *find_access_point(NMDeviceWifi *device,
                                        const char *ssid,
                                        const char *bssid) {
    const GPtrArray *points = nm_device_wifi_get_access_points(device);
    NMAccessPoint *best = NULL;
    for (guint index = 0; points && index < points->len; ++index) {
        NMAccessPoint *point = g_ptr_array_index((GPtrArray *) points, index);
        if (!ssid_matches(nm_access_point_get_ssid(point), ssid))
            continue;
        if (bssid && *bssid) {
            if (g_ascii_strcasecmp(nm_access_point_get_bssid(point), bssid) == 0)
                return point;
            continue;
        }
        if (!best || nm_access_point_get_strength(point) > nm_access_point_get_strength(best))
            best = point;
    }
    return best;
}

static const char *detect_security(NMAccessPoint *point, const char *hint) {
    NM80211ApFlags flags;
    NM80211ApSecurityFlags wpa;
    NM80211ApSecurityFlags rsn;
    NM80211ApSecurityFlags all;
    if (!point)
        return hint && *hint ? hint : "open";
    flags = nm_access_point_get_flags(point);
    wpa = nm_access_point_get_wpa_flags(point);
    rsn = nm_access_point_get_rsn_flags(point);
    all = wpa | rsn;
    if (all & NM_802_11_AP_SEC_KEY_MGMT_802_1X)
        return "enterprise";
    if (all & NM_802_11_AP_SEC_KEY_MGMT_OWE)
        return "owe";
    if ((all & NM_802_11_AP_SEC_KEY_MGMT_SAE)
            && (all & NM_802_11_AP_SEC_KEY_MGMT_PSK))
        return "transition";
    if (all & NM_802_11_AP_SEC_KEY_MGMT_SAE)
        return "sae";
    if (all & NM_802_11_AP_SEC_KEY_MGMT_PSK)
        return "psk";
    if ((flags & NM_802_11_AP_FLAGS_PRIVACY) != 0)
        return "wep";
    return "open";
}

static NMRemoteConnection *find_saved_connection(ConnectRequest *request) {
    const GPtrArray *connections = nm_client_get_connections(request->client);
    for (guint index = 0; connections && index < connections->len; ++index) {
        NMRemoteConnection *remote = g_ptr_array_index((GPtrArray *) connections, index);
        NMSettingWireless *wireless = nm_connection_get_setting_wireless(NM_CONNECTION(remote));
        if (!wireless || !ssid_matches(nm_setting_wireless_get_ssid(wireless), request->ssid))
            continue;
        if (request->access_point
                && !nm_access_point_connection_valid(request->access_point,
                                                     NM_CONNECTION(remote)))
            continue;
        return remote;
    }
    return NULL;
}

static NMRemoteConnection *find_profile_by_uuid(ConnectRequest *request) {
    if (!request->profile_uuid)
        return NULL;
    return nm_client_get_connection_by_uuid(request->client, request->profile_uuid);
}

static void remove_temporary_profile(ConnectRequest *request) {
    GError *error = NULL;
    NMRemoteConnection *remote;
    if (!request->created_profile)
        return;
    remote = request->active ? nm_active_connection_get_connection(request->active)
                             : find_profile_by_uuid(request);
    if (remote)
        nm_remote_connection_delete(remote, NULL, &error);
    g_clear_error(&error);
}

static const char *reason_code(NMDeviceStateReason reason) {
    switch (reason) {
    case NM_DEVICE_STATE_REASON_NO_SECRETS:
    case NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT:
    case NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED:
    case NM_DEVICE_STATE_REASON_SUPPLICANT_FAILED:
        return "incorrect-password";
    case NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT:
        return "authentication-timeout";
    case NM_DEVICE_STATE_REASON_SSID_NOT_FOUND:
    case NM_DEVICE_STATE_REASON_REMOVED:
        return "access-point-disappeared";
    case NM_DEVICE_STATE_REASON_IP_CONFIG_UNAVAILABLE:
    case NM_DEVICE_STATE_REASON_IP_CONFIG_EXPIRED:
    case NM_DEVICE_STATE_REASON_DHCP_START_FAILED:
    case NM_DEVICE_STATE_REASON_DHCP_ERROR:
    case NM_DEVICE_STATE_REASON_DHCP_FAILED:
        return "dhcp-failed";
    case NM_DEVICE_STATE_REASON_CONNECTION_REMOVED:
        return "profile-creation-failed";
    default:
        return "activation-failed";
    }
}

static const char *current_failure_code(ConnectRequest *request) {
    NMDeviceStateReason reason;
    if (!nm_client_wireless_get_enabled(request->client)
            || !nm_client_wireless_hardware_get_enabled(request->client))
        return "wifi-disabled";
    reason = nm_device_get_state_reason(NM_DEVICE(request->device));
    if (reason == NM_DEVICE_STATE_REASON_NONE)
        reason = request->last_device_reason;
    return reason_code(reason);
}

static const char *activation_error_code(GError *error, ConnectRequest *request) {
    const NMDeviceStateReason reason = request->device
        ? nm_device_get_state_reason(NM_DEVICE(request->device))
        : NM_DEVICE_STATE_REASON_NONE;
    if (error && g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
        return "cancelled";
    if (error && g_error_matches(error, NM_MANAGER_ERROR,
                                 NM_MANAGER_ERROR_PERMISSION_DENIED))
        return "permission-denied";
    if (error && g_error_matches(error, NM_MANAGER_ERROR,
                                 NM_MANAGER_ERROR_UNKNOWN_DEVICE))
        return "adapter-unavailable";
    if (error && g_error_matches(error, NM_MANAGER_ERROR,
                                 NM_MANAGER_ERROR_CONNECTION_NOT_AVAILABLE))
        return "access-point-disappeared";
    if (error && g_error_matches(error, NM_DEVICE_ERROR,
                                 NM_DEVICE_ERROR_SPECIFIC_OBJECT_NOT_FOUND))
        return "access-point-disappeared";
    if (request->device) {
        const char *code = current_failure_code(request);
        if (reason != NM_DEVICE_STATE_REASON_NONE
                || request->last_device_reason != NM_DEVICE_STATE_REASON_NONE
                || g_strcmp0(code, "wifi-disabled") == 0)
            return code;
    }
    return "activation-failed";
}

static void finish_request(ConnectRequest *request, int exit_code, const char *error_code) {
    if (request->finished)
        return;
    request->finished = TRUE;
    request->exit_code = exit_code;
    if (request->timeout_id) {
        g_source_remove(request->timeout_id);
        request->timeout_id = 0;
    }
    if (error_code)
        emit_error(error_code);
    secure_clear(&request->passphrase);
    g_main_loop_quit(request->loop);
}

static void profile_persisted(GObject *source, GAsyncResult *result, gpointer user_data) {
    ConnectRequest *request = user_data;
    GError *error = NULL;
    GVariant *result_data = nm_remote_connection_update2_finish(
        NM_REMOTE_CONNECTION(source), result, &error);
    request->persisting_profile = FALSE;
    if (!result_data) {
        if (request->active)
            nm_client_deactivate_connection(request->client, request->active, NULL, NULL);
        remove_temporary_profile(request);
        g_clear_error(&error);
        if (request->profile)
            nm_connection_clear_secrets(request->profile);
        finish_request(request, 12, "profile-creation-failed");
        return;
    }
    g_variant_unref(result_data);
    if (request->profile)
        nm_connection_clear_secrets(request->profile);
    emit_state("connected");
    finish_request(request, 0, NULL);
}

static void active_state_changed(GObject *object, GParamSpec *spec, gpointer user_data) {
    ConnectRequest *request = user_data;
    NMActiveConnectionState state = nm_active_connection_get_state(NM_ACTIVE_CONNECTION(object));
    (void) spec;
    if (state == NM_ACTIVE_CONNECTION_STATE_ACTIVATED) {
        if (request->created_profile) {
            NMRemoteConnection *remote = nm_active_connection_get_connection(request->active);
            GVariant *settings;
            GVariantBuilder args;
            if (request->persisting_profile)
                return;
            if (!remote || !request->profile) {
                remove_temporary_profile(request);
                finish_request(request, 12, "profile-creation-failed");
                return;
            }
            request->persisting_profile = TRUE;
            settings = nm_connection_to_dbus(request->profile,
                NM_CONNECTION_SERIALIZE_WITH_NON_SECRET
                | NM_CONNECTION_SERIALIZE_WITH_SECRETS);
            g_variant_builder_init(&args, G_VARIANT_TYPE("a{sv}"));
            nm_remote_connection_update2(remote, settings,
                NM_SETTINGS_UPDATE2_FLAG_TO_DISK, g_variant_builder_end(&args),
                request->cancellable, profile_persisted, request);
            g_variant_unref(settings);
            return;
        }
        emit_state("connected");
        finish_request(request, 0, NULL);
    } else if (state == NM_ACTIVE_CONNECTION_STATE_DEACTIVATED) {
        const char *code = current_failure_code(request);
        remove_temporary_profile(request);
        finish_request(request, 10, code);
    }
}

static void device_state_changed(NMDevice *device,
                                 NMDeviceState new_state,
                                 NMDeviceState old_state,
                                 NMDeviceStateReason reason,
                                 gpointer user_data) {
    ConnectRequest *request = user_data;
    (void) device;
    (void) old_state;
    request->last_device_reason = reason;
    if (request->finished)
        return;
    if (new_state == NM_DEVICE_STATE_PREPARE
            || new_state == NM_DEVICE_STATE_CONFIG
            || new_state == NM_DEVICE_STATE_NEED_AUTH)
        emit_state("authenticating");
    else if (new_state == NM_DEVICE_STATE_IP_CONFIG
            || new_state == NM_DEVICE_STATE_IP_CHECK
            || new_state == NM_DEVICE_STATE_SECONDARIES)
        emit_state("connecting");
    else if (new_state == NM_DEVICE_STATE_FAILED) {
        remove_temporary_profile(request);
        finish_request(request, 10, current_failure_code(request));
    }
}

static void activation_ready(GObject *source, GAsyncResult *result, gpointer user_data) {
    ConnectRequest *request = user_data;
    GError *error = NULL;
    GVariant *result_data = NULL;
    NMActiveConnection *active;
    if (request->created_profile)
        active = nm_client_add_and_activate_connection2_finish(
            NM_CLIENT(source), result, &result_data, &error);
    else
        active = nm_client_activate_connection_finish(NM_CLIENT(source), result, &error);
    if (result_data)
        g_variant_unref(result_data);
    if (!active) {
        const char *code = activation_error_code(error, request);
        remove_temporary_profile(request);
        g_clear_error(&error);
        finish_request(request, 10, code);
        return;
    }
    request->active = g_object_ref(active);
    secure_clear(&request->passphrase);
    g_signal_connect(request->active, "notify::state",
                     G_CALLBACK(active_state_changed), request);
    active_state_changed(G_OBJECT(request->active), NULL, request);
}

static gboolean connection_timeout(gpointer user_data) {
    ConnectRequest *request = user_data;
    request->timeout_id = 0;
    g_cancellable_cancel(request->cancellable);
    if (request->active)
        nm_client_deactivate_connection(request->client, request->active, NULL, NULL);
    remove_temporary_profile(request);
    finish_request(request, 11, "authentication-timeout");
    return G_SOURCE_REMOVE;
}

static gboolean cancel_request(gpointer user_data) {
    ConnectRequest *request = user_data;
    g_cancellable_cancel(request->cancellable);
    if (request->active)
        nm_client_deactivate_connection(request->client, request->active, NULL, NULL);
    remove_temporary_profile(request);
    finish_request(request, 130, "cancelled");
    return G_SOURCE_REMOVE;
}

static gboolean valid_text(const char *value, size_t maximum) {
    size_t length;
    if (!value || !g_utf8_validate(value, -1, NULL))
        return FALSE;
    length = strlen(value);
    if (length == 0 || length > maximum)
        return FALSE;
    for (const unsigned char *cursor = (const unsigned char *) value; *cursor; ++cursor) {
        if (*cursor < 0x20 || *cursor == 0x7f)
            return FALSE;
    }
    return TRUE;
}

static int acquire_activation_lock(ConnectRequest *request) {
    const char *runtime_root = g_get_user_runtime_dir();
    char *state_directory;
    char *lock_path;
    struct stat info;
    if (!runtime_root || runtime_root[0] != '/') {
        emit_error("activation-failed");
        return 70;
    }
    state_directory = g_build_filename(runtime_root, "voidline", NULL);
    if (g_mkdir_with_parents(state_directory, 0700) != 0
            || lstat(state_directory, &info) != 0
            || !S_ISDIR(info.st_mode)
            || info.st_uid != getuid()) {
        g_free(state_directory);
        emit_error("activation-failed");
        return 70;
    }
    lock_path = g_build_filename(state_directory, "network-activation.lock", NULL);
    g_free(state_directory);
    request->lock_fd = open(lock_path,
                            O_CREAT | O_CLOEXEC | O_RDWR | O_NOFOLLOW,
                            S_IRUSR | S_IWUSR);
    g_free(lock_path);
    if (request->lock_fd < 0
            || fstat(request->lock_fd, &info) != 0
            || !S_ISREG(info.st_mode)
            || info.st_uid != getuid()) {
        if (request->lock_fd >= 0) {
            close(request->lock_fd);
            request->lock_fd = -1;
        }
        emit_error("activation-failed");
        return 70;
    }
    if (fchmod(request->lock_fd, S_IRUSR | S_IWUSR) != 0) {
        close(request->lock_fd);
        request->lock_fd = -1;
        emit_error("activation-failed");
        return 70;
    }
    if (flock(request->lock_fd, LOCK_EX | LOCK_NB) != 0) {
        const int saved_errno = errno;
        close(request->lock_fd);
        request->lock_fd = -1;
        emit_error(saved_errno == EWOULDBLOCK ? "busy" : "activation-failed");
        return saved_errno == EWOULDBLOCK ? 75 : 70;
    }
    return 0;
}

static char *read_passphrase(void) {
    char *line = NULL;
    size_t capacity = 0;
    ssize_t length = getline(&line, &capacity, stdin);
    if (length < 0) {
        free(line);
        return g_strdup("");
    }
    while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r'))
        line[--length] = 0;
    char *copy = g_strndup(line, 64);
    volatile char *cursor = (volatile char *) line;
    while (capacity-- > 0)
        *cursor++ = 0;
    free(line);
    return copy;
}

static gboolean valid_personal_password(const char *value, const char *security) {
    size_t length = value ? strlen(value) : 0;
    if (g_strcmp0(security, "sae") == 0)
        return length >= 1 && length <= 63;
    if (length >= 8 && length <= 63)
        return TRUE;
    if (length != 64)
        return FALSE;
    for (size_t index = 0; index < length; ++index) {
        if (!g_ascii_isxdigit(value[index]))
            return FALSE;
    }
    return TRUE;
}

static NMConnection *create_profile(ConnectRequest *request, const char *security) {
    NMConnection *connection = nm_simple_connection_new();
    NMSetting *connection_setting = nm_setting_connection_new();
    NMSetting *wireless_setting = nm_setting_wireless_new();
    GBytes *ssid_bytes = g_bytes_new(request->ssid, strlen(request->ssid));
    request->profile_uuid = nm_utils_uuid_generate();
    g_object_set(connection_setting,
                 NM_SETTING_CONNECTION_ID, request->ssid,
                 NM_SETTING_CONNECTION_UUID, request->profile_uuid,
                 NM_SETTING_CONNECTION_TYPE, NM_SETTING_WIRELESS_SETTING_NAME,
                 NM_SETTING_CONNECTION_AUTOCONNECT, TRUE,
                 NULL);
    nm_connection_add_setting(connection, connection_setting);
    g_object_set(wireless_setting,
                 NM_SETTING_WIRELESS_SSID, ssid_bytes,
                 NM_SETTING_WIRELESS_MODE, NM_SETTING_WIRELESS_MODE_INFRA,
                 NM_SETTING_WIRELESS_HIDDEN, request->hidden,
                 NULL);
    g_bytes_unref(ssid_bytes);
    nm_connection_add_setting(connection, wireless_setting);
    if (g_strcmp0(security, "open") != 0) {
        NMSetting *security_setting = nm_setting_wireless_security_new();
        const char *key_mgmt = g_strcmp0(security, "sae") == 0 ? "sae"
                              : g_strcmp0(security, "owe") == 0 ? "owe"
                              : "wpa-psk";
        g_object_set(security_setting,
                     NM_SETTING_WIRELESS_SECURITY_KEY_MGMT, key_mgmt,
                     NULL);
        if (g_strcmp0(security, "owe") != 0)
            g_object_set(security_setting,
                         NM_SETTING_WIRELESS_SECURITY_PSK, request->passphrase,
                         NULL);
        nm_connection_add_setting(connection, security_setting);
    }
    return connection;
}

static int run_connect(ConnectRequest *request) {
    GError *error = NULL;
    NMRemoteConnection *saved;
    const char *security;
    const char *specific_object;
    GVariantBuilder options;
    request->client = nm_client_new(NULL, &error);
    if (!request->client) {
        g_clear_error(&error);
        emit_error("networkmanager-unavailable");
        return 20;
    }
    if (!nm_client_networking_get_enabled(request->client)
            || !nm_client_wireless_get_enabled(request->client)) {
        emit_error("wifi-disabled");
        return 21;
    }
    request->device = find_wifi_device(request->client, request->interface_name);
    if (!request->device) {
        emit_error("adapter-unavailable");
        return 22;
    }
    request->access_point = find_access_point(request->device, request->ssid, request->bssid);
    saved = find_saved_connection(request);
    if (!request->hidden && !request->access_point && !saved) {
        emit_error("access-point-disappeared");
        return 23;
    }
    security = detect_security(request->access_point, request->security_hint);
    if (g_strcmp0(security, "enterprise") == 0) {
        if (!saved) {
            emit_error("unsupported-enterprise");
            return 24;
        }
    } else if (g_strcmp0(security, "wep") == 0) {
        emit_error("unsupported-security");
        return 24;
    }
    specific_object = request->access_point ? nm_object_get_path(NM_OBJECT(request->access_point))
                                            : NULL;
    g_signal_connect(request->device, "state-changed",
                     G_CALLBACK(device_state_changed), request);
    if (saved) {
        request->created_profile = FALSE;
        emit_state("connecting");
        secure_clear(&request->passphrase);
        nm_client_activate_connection_async(request->client, NM_CONNECTION(saved),
                                            NM_DEVICE(request->device), specific_object,
                                            request->cancellable,
                                            activation_ready, request);
    } else {
        if (g_strcmp0(security, "open") != 0
                && g_strcmp0(security, "owe") != 0
                && !valid_personal_password(request->passphrase, security)) {
            emit_error("invalid-credentials");
            return 25;
        }
        request->created_profile = TRUE;
        emit_state("creating-profile");
        request->profile = create_profile(request, security);
        g_variant_builder_init(&options, G_VARIANT_TYPE("a{sv}"));
        g_variant_builder_add(&options, "{sv}", "persist", g_variant_new_string("memory"));
        nm_client_add_and_activate_connection2(request->client, request->profile,
                                                NM_DEVICE(request->device), specific_object,
                                                g_variant_builder_end(&options),
                                                request->cancellable,
                                                activation_ready, request);
    }
    request->timeout_id = g_timeout_add_seconds(40, connection_timeout, request);
    g_main_loop_run(request->loop);
    return request->exit_code;
}

int main(int argc, char **argv) {
    ConnectRequest request = {0};
    const char *command;
    request.exit_code = 1;
    request.lock_fd = -1;
    request.cancellable = g_cancellable_new();
    if (argc < 2 || g_strcmp0(argv[1], "connect") != 0) {
        g_printerr("usage: voidline-network connect --interface IFACE --ssid SSID [--bssid BSSID] [--security TYPE] [--hidden]\n");
        return 64;
    }
    command = argv[1];
    (void) command;
    for (int index = 2; index < argc; ++index) {
        if (g_strcmp0(argv[index], "--interface") == 0 && ++index < argc)
            request.interface_name = g_strdup(argv[index]);
        else if (g_strcmp0(argv[index], "--ssid") == 0 && ++index < argc)
            request.ssid = g_strdup(argv[index]);
        else if (g_strcmp0(argv[index], "--bssid") == 0 && ++index < argc)
            request.bssid = g_strdup(argv[index]);
        else if (g_strcmp0(argv[index], "--security") == 0 && ++index < argc)
            request.security_hint = g_strdup(argv[index]);
        else if (g_strcmp0(argv[index], "--hidden") == 0)
            request.hidden = TRUE;
        else {
            g_printerr("invalid argument\n");
            return 64;
        }
    }
    if (!valid_text(request.interface_name, 32) || !valid_text(request.ssid, 32)) {
        g_printerr("invalid network identity\n");
        return 64;
    }
    int lock_result = acquire_activation_lock(&request);
    if (lock_result != 0)
        return lock_result;
    request.passphrase = read_passphrase();
    request.loop = g_main_loop_new(NULL, FALSE);
    g_unix_signal_add(SIGINT, cancel_request, &request);
    g_unix_signal_add(SIGTERM, cancel_request, &request);
    int result = run_connect(&request);
    secure_clear(&request.passphrase);
    if (request.profile)
        nm_connection_clear_secrets(request.profile);
    g_clear_object(&request.profile);
    g_clear_object(&request.active);
    g_clear_object(&request.cancellable);
    g_clear_object(&request.client);
    g_clear_pointer(&request.loop, g_main_loop_unref);
    g_clear_pointer(&request.ssid, g_free);
    g_clear_pointer(&request.bssid, g_free);
    g_clear_pointer(&request.interface_name, g_free);
    g_clear_pointer(&request.security_hint, g_free);
    g_clear_pointer(&request.profile_uuid, g_free);
    if (request.lock_fd >= 0)
        close(request.lock_fd);
    return result;
}
