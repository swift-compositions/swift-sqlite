func start(_ hub: Hub) { Task.detached { for await _ in hub.follow() {} } }
