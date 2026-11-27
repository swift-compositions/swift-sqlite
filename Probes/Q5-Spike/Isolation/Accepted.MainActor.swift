@MainActor func onMain(_ hub: Hub) async { for await _ in hub.follow() {} }
