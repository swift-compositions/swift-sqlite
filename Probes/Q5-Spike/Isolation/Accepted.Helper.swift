// The sequence handed to a nonisolated async helper, which runs on the caller's actor (nonsending by default).
func drain(_ values: Values) async { for await _ in values {} }
actor Listener { func listen(_ hub: Hub) async { await drain(hub.follow()) } }
