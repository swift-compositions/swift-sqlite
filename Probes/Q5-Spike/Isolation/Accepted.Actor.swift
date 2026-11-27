actor Listener { func listen(_ hub: Hub) async { for await _ in hub.follow() {} } }
