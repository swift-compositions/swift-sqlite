// Asked for with another actor named explicitly, from a task with no isolation.
actor Listener {}
func start(_ hub: Hub, _ listener: Listener) {
    Task.detached {
        let values = await hub.follow(isolation: listener)
        for await _ in values {}
    }
}
