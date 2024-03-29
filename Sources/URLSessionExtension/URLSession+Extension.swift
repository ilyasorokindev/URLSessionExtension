//
//  URLSession+Extension.swift
//  URLSessionExtension
//
//  Created by Ilya Sorokin on 11.11.2020.
//

import Foundation

public enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case head = "HEAD"
    case delete = "DELETE"
    case patch = "PATCH"
    case option = "OPTIONS"
}

public enum Response<T> {
    case error(error: Error)
    case result(model: T)
}

private enum Constants {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
}

extension URLSession {
    
    public enum CoreError: Error {
        case unknownError
        case jsonDecodeError(response: String)
    }
    
    public typealias ResponseMapper<T> = (
        _ data: Data?,
        _ response: URLResponse?,
        _ error: Error?) -> Response<T>
    
    public func makeURLRequest<T>(
        urlString: String,
        httpMethod: HttpMethod,
        object: T?,
        userAgent: String? = nil) -> URLRequest
    where T: Encodable {
        guard let url = URL(string: urlString) else {
            fatalError("Wrong urlString")
        }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        if let object = object {
            guard let jsonData =  try? Constants.encoder.encode(object) else {
                fatalError("incorrect object")
            }
            request.httpBody = jsonData
        }
        return request
    }
    
    public func makeURLRequest(
        urlString: String,
        httpMethod: HttpMethod = .get,
        userAgent: String? = nil) -> URLRequest {
        let object: String? = nil
        return makeURLRequest(urlString: urlString, httpMethod: httpMethod, object: object, userAgent: userAgent)
    }
    
    public func execute<T>(
        request: URLRequest,
        responseMapper: ResponseMapper<T>? = nil,
        responseClosure: @escaping(_ response: Response<T>) -> Void)
    where T: Decodable {
        let task = self.dataTask(with: request) { data, response, error in
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }
            let map: () -> Response<T> = {
                if let error = error {
                    return Response<T>.error(error: error)
                }
                if let data = data {
                    do {
                        let model = try Constants.decoder.decode(T.self, from: data)
                        return Response<T>.result(model: model)
                    } catch let jsonError as NSError {
                        return Response<T>.error(error: CoreError.jsonDecodeError(response: "JSON decode failed: \(jsonError.localizedDescription)"))
                    }
                }
                assertionFailure("decoding is incorrect")
                return Response<T>.error(error: CoreError.unknownError)
            }
            let value: Response<T> = responseMapper?(data, response, error) ?? map()
            
            DispatchQueue.main.async {
                responseClosure(value)
            }
            
        }
        task.resume()
    }
}
