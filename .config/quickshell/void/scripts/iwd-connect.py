#!/usr/bin/python3
"""Connect to an iwd network through a short-lived credential agent.

The passphrase is read from stdin so it never appears in the process command
line.  iwd requests it over D-Bus only if the selected network needs it.
"""

from __future__ import annotations

import sys
from typing import Any

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib


IWD_SERVICE = "net.connman.iwd"
AGENT_MANAGER_PATH = "/net/connman/iwd"
AGENT_MANAGER_INTERFACE = "net.connman.iwd.AgentManager"
AGENT_INTERFACE = "net.connman.iwd.Agent"
DEVICE_INTERFACE = "net.connman.iwd.Device"
NETWORK_INTERFACE = "net.connman.iwd.Network"
STATION_INTERFACE = "net.connman.iwd.Station"
OBJECT_MANAGER_INTERFACE = "org.freedesktop.DBus.ObjectManager"
AGENT_PATH = "/org/voidline/iwd/credential_agent"


class CredentialCanceled(dbus.DBusException):
    _dbus_error_name = "net.connman.iwd.Agent.Error.Canceled"


class CredentialAgent(dbus.service.Object):
    def __init__(self, bus: dbus.SystemBus, passphrase: str, loop: GLib.MainLoop):
        super().__init__(bus, AGENT_PATH)
        self.passphrase = passphrase
        self.loop = loop

    def _secret(self) -> str:
        if not self.passphrase:
            raise CredentialCanceled("No credential was supplied")
        return self.passphrase

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Release(self) -> None:
        self.passphrase = ""
        if self.loop.is_running():
            self.loop.quit()

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPassphrase(self, _network: dbus.ObjectPath) -> str:
        return self._secret()

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPrivateKeyPassphrase(self, _network: dbus.ObjectPath) -> str:
        return self._secret()

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="ss")
    def RequestUserNameAndPassword(self, _network: dbus.ObjectPath) -> tuple[str, str]:
        return "", self._secret()

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="s")
    def RequestUserPassword(self, _network: dbus.ObjectPath, _user: str) -> str:
        return self._secret()

    @dbus.service.method(AGENT_INTERFACE, in_signature="s", out_signature="")
    def Cancel(self, _reason: str) -> None:
        self.passphrase = ""


def object_interfaces(bus: dbus.SystemBus) -> dict[dbus.ObjectPath, Any]:
    manager = dbus.Interface(
        bus.get_object(IWD_SERVICE, "/"), OBJECT_MANAGER_INTERFACE
    )
    return manager.GetManagedObjects()


def find_station(objects: dict[dbus.ObjectPath, Any], interface_name: str) -> str:
    for path, interfaces in objects.items():
        device = interfaces.get(DEVICE_INTERFACE)
        if device and str(device.get("Name", "")) == interface_name:
            if STATION_INTERFACE in interfaces:
                return str(path)
    raise RuntimeError(f"Wi-Fi adapter {interface_name!r} is not managed by iwd")


def find_network(
    objects: dict[dbus.ObjectPath, Any], station_path: str, ssid: str, security: str
) -> str:
    candidates: list[str] = []
    for path, interfaces in objects.items():
        network = interfaces.get(NETWORK_INTERFACE)
        if not network:
            continue
        if str(network.get("Device", "")) != station_path:
            continue
        if str(network.get("Name", "")) != ssid:
            continue
        network_type = str(network.get("Type", ""))
        if security and network_type == security:
            return str(path)
        candidates.append(str(path))
    if candidates:
        return candidates[0]
    raise RuntimeError(f"Network {ssid!r} is no longer available; scan again")


def error_text(error: dbus.DBusException, secured: bool) -> str:
    name = error.get_dbus_name() or "net.connman.iwd.Error.Failed"
    message = str(error).strip() or name
    lowered = f"{name} {message}".lower()
    if "timed" in lowered:
        return f"Connection timed out: {message}"
    if "notfound" in lowered or "not found" in lowered or "not available" in lowered:
        return f"Network unavailable: {message}"
    if secured and ("failed" in lowered or "psk" in lowered or "secret" in lowered):
        return f"Authentication failed: {message}"
    return f"Connection failed: {message}"


def main() -> int:
    if len(sys.argv) != 6:
        print(
            "Usage: iwd-connect.py INTERFACE SSID SECURITY HIDDEN KNOWN",
            file=sys.stderr,
        )
        return 64

    interface_name, ssid, security, hidden_value, _known_value = sys.argv[1:]
    hidden = hidden_value == "1"
    passphrase = sys.stdin.readline().rstrip("\r\n")

    if not interface_name or not ssid or security not in {"", "open", "psk", "8021x"}:
        print("Invalid network connection request", file=sys.stderr)
        return 64
    if security == "8021x":
        print("Enterprise EAP profiles require advanced provisioning", file=sys.stderr)
        return 11

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    bus = dbus.SystemBus(private=True)
    agent = CredentialAgent(bus, passphrase, loop)
    manager = dbus.Interface(
        bus.get_object(IWD_SERVICE, AGENT_MANAGER_PATH), AGENT_MANAGER_INTERFACE
    )
    registered = False
    result = {"exit": 1, "error": "Connection failed"}

    def succeeded() -> None:
        result["exit"] = 0
        result["error"] = ""
        loop.quit()

    def failed(error: dbus.DBusException) -> None:
        result["exit"] = 1
        result["error"] = error_text(error, security != "open")
        loop.quit()

    def timed_out() -> bool:
        result["exit"] = 124
        result["error"] = "Connection timed out while waiting for iwd"
        loop.quit()
        return GLib.SOURCE_REMOVE

    try:
        objects = object_interfaces(bus)
        station_path = find_station(objects, interface_name)
        manager.RegisterAgent(AGENT_PATH)
        registered = True

        if hidden:
            method = bus.get_object(IWD_SERVICE, station_path).get_dbus_method(
                "ConnectHiddenNetwork", STATION_INTERFACE
            )
            method(dbus.String(ssid), reply_handler=succeeded, error_handler=failed)
        else:
            network_path = find_network(objects, station_path, ssid, security)
            method = bus.get_object(IWD_SERVICE, network_path).get_dbus_method(
                "Connect", NETWORK_INTERFACE
            )
            method(reply_handler=succeeded, error_handler=failed)

        GLib.timeout_add_seconds(30, timed_out)
        loop.run()
    except (dbus.DBusException, RuntimeError) as error:
        result["exit"] = 1
        result["error"] = error_text(error, security != "open") if isinstance(
            error, dbus.DBusException
        ) else str(error)
    finally:
        agent.passphrase = ""
        if registered:
            try:
                manager.UnregisterAgent(AGENT_PATH)
            except dbus.DBusException:
                pass
        agent.remove_from_connection()
        bus.close()

    if result["error"]:
        print(result["error"], file=sys.stderr)
    return int(result["exit"])


if __name__ == "__main__":
    raise SystemExit(main())
