@concurrent func drain(_ values: Values) async { for await _ in values {} }
actor Listener { func listen(_ hub: Hub) async { await drain(hub.follow()) } }
