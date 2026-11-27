// Asked for on an actor, iterated in a task with no isolation.
actor Listener {
    func listen(_ hub: Hub) {
        let values = hub.follow()
        Task.detached { for await _ in values {} }
    }
}
