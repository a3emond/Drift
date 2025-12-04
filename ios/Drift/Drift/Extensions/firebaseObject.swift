import Foundation

extension Encodable {
    var firebaseObject: Any {
        guard let data = try? JSONEncoder().encode(self),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return [:]   // never crash on encode error
        }
        return obj
    }
}
