func listen(_ hub: Hub, on actor: isolated (any Actor)?) async { for await _ in hub.follow() {} }
