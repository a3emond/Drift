import Foundation
import FirebaseStorage

final class StorageService {

    private let storage: Storage
    private let logger: Logging

    init(storage: Storage = Storage.storage(),
         logger: Logging = DriftLogger.shared) {
        self.storage = storage
        self.logger = logger

        logger.debug("StorageService initialized",
                     category: .storage)
    }

    // ----------------------------------------------------------
    // MARK: - Upload Helpers
    // ----------------------------------------------------------

    func uploadData(_ data: Data,
                    to path: StoragePath,
                    contentType: String) async throws -> URL {

        logger.debug("uploadData to \(path.value) contentType=\(contentType)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        let metadata = StorageMetadata()
        metadata.contentType = contentType

        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL()

            logger.info("uploadData success \(path.value)",
                        category: .storage)

            return url
        } catch {
            logger.error("uploadData failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }

    func uploadFile(_ fileURL: URL,
                    to path: StoragePath,
                    contentType: String) async throws -> URL {

        logger.debug("uploadFile from \(fileURL.lastPathComponent) to \(path.value) contentType=\(contentType)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        let metadata = StorageMetadata()
        metadata.contentType = contentType

        do {
            _ = try await ref.putFileAsync(from: fileURL, metadata: metadata)
            let url = try await ref.downloadURL()

            logger.info("uploadFile success \(path.value)",
                        category: .storage)

            return url
        } catch {
            logger.error("uploadFile failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }

    // ----------------------------------------------------------
    // MARK: - Download Helpers
    // ----------------------------------------------------------

    func downloadData(from path: StoragePath,
                      maxSize: Int64 = 25 * 1024 * 1024) async throws -> Data {

        logger.debug("downloadData from \(path.value) maxSize=\(maxSize)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        do {
            let data = try await ref.data(maxSize: maxSize)

            logger.info("downloadData success \(path.value) size=\(data.count)",
                        category: .storage)

            return data
        } catch {
            logger.error("downloadData failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }

    func downloadURL(for path: StoragePath) async throws -> URL {

        logger.debug("downloadURL for \(path.value)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        do {
            let url = try await ref.downloadURL()

            logger.info("downloadURL success \(path.value)",
                        category: .storage)

            return url
        } catch {
            logger.error("downloadURL failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }

    // ----------------------------------------------------------
    // MARK: - Delete
    // ----------------------------------------------------------

    func delete(_ path: StoragePath) async throws {

        logger.debug("delete \(path.value)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        do {
            try await ref.delete()

            logger.info("delete success \(path.value)",
                        category: .storage)

        } catch {
            logger.error("delete failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }
}
