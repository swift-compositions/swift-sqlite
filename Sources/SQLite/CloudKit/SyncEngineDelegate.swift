#if CloudKit
#if canImport(CloudKit)
  public import CloudKit

  public protocol SyncEngineDelegate: AnyObject, Sendable {
    func syncEngine(
      _ syncEngine: SyncEngine,
      accountChanged changeType: CKSyncEngine.Event.AccountChange.ChangeType
    ) async
  }

  extension SyncEngineDelegate {
    public func syncEngine(
      _ syncEngine: SyncEngine,
      accountChanged changeType: CKSyncEngine.Event.AccountChange.ChangeType
    ) async {
      switch changeType {
      case .signOut, .switchAccounts:
        do {
          try await syncEngine.deleteLocalData()
        } catch {
          syncEngine.surface(SyncEngine.Error(error))
        }
      case .signIn:
        break
      @unknown default:
        break
      }
    }
  }
#endif

#endif
