//
//  Copyright © Essential Developer. All rights reserved.
//

import CoreData

public final class CoreDataFeedStore: FeedStore {
	public static let modelName = "FeedStore"
	public static let model = NSManagedObjectModel(name: modelName,
	                                               in: Bundle(for: CoreDataFeedStore.self))

	private let container: NSPersistentContainer
	private let context: NSManagedObjectContext

	public struct ModelNotFound: Error {
		public let modelName: String
	}

	public init(storeURL: URL) throws {
		guard let model = CoreDataFeedStore.model else {
			throw ModelNotFound(modelName: CoreDataFeedStore.modelName)
		}

		container = try NSPersistentContainer.load(
			name: CoreDataFeedStore.modelName,
			model: model,
			url: storeURL
		)
		context = container.newBackgroundContext()
	}

	deinit {
		cleanUpReferencesToPersistentStores()
	}

	private func cleanUpReferencesToPersistentStores() {
		context.performAndWait {
			let coordinator = self.container.persistentStoreCoordinator
			try? coordinator.persistentStores.forEach(coordinator.remove)
		}
	}

	public func retrieve(completion: @escaping RetrievalCompletion) {
		guard let entityName = ManagedCache.entity().name
		else { return completion(.empty) }

		perform { context in
			do {
				let request = NSFetchRequest<ManagedCache>(entityName: entityName)
				request.returnsObjectsAsFaults = false
				guard let cache = try ManagedCache.find(in: context) else {
					return completion(.empty)
				}
				completion(.found(feed: cache.localFeed,
				                  timestamp: cache.timestamp))
			} catch {
				completion(.failure(error))
			}
		}
	}

	public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		perform { context in
			do {
				let managedCache = try ManagedCache.newUniqueInstance(in: context)
				managedCache.timestamp = timestamp
				managedCache.feed = ManagedFeedImage.images(from: feed,
				                                            in: context)

				try context.save()
				completion(nil)
			} catch {
				completion(error)
			}
		}
	}

	public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		perform { context in
			do {
				try ManagedCache
					.find(in: context)
					.map(context.delete)
					.map(context.save)
				completion(nil)
			} catch {
				completion(error)
			}
		}
	}

	private func perform(_ action: @escaping (NSManagedObjectContext) -> Void) {
		let context = self.context
		context.perform { action(context) }
	}
}
