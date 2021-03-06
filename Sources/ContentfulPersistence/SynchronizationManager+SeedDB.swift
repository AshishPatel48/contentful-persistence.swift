//
//  SynchronizationManager+SeedDB.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 06.09.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation
import Contentful
import ObjectMapper

public extension SynchronizationManager {

    /**
     This method will seed a CoreData datastore from a directory of JSON files in the specified Bundle.
     Use this method in conjunction with the ContentfulBundleSync command line interface.
    
     - Parameter directory: The name of the directory in your bundle which contains your Contentful JSON and media assets generated by the CLI.
     - Parameter bundle: The bundle in which your directory containing your Contentful data is located.

     - Throws: Errors if the media the files in the directory can't be deserialized.

     */
    public func seedDBFromJSONFiles(in directory: String, in bundle: Bundle) throws {

        var fileIndex = 0
        let filePaths = bundle.paths(forResourcesOfType: "json", inDirectory: directory)

        let firstFilePath = filePaths.filter({ URL(string: $0)?.deletingPathExtension().lastPathComponent == String(fileIndex) }).first
        guard let initialSyncJSONFilePath = firstFilePath else {
            throw DatabaseSeedingError.invalidFilePath
        }


        var filePath: String? = initialSyncJSONFilePath
        while let path = filePath {

            guard let data = FileManager.default.contents(atPath: path) else {
                let error = SDKError.invalidURL(string: path)
                throw error
            }
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                let error = SDKError.unparseableJSON(data: data, errorMessage: "Foundation.JSONSerialization failed")
                throw error
            }

            let map = Map(mappingType: .fromJSON, JSON: json)
            let syncSpace = try SyncSpace(map: map)
            self.update(with: syncSpace)

            fileIndex += 1
            filePath = filePaths.filter({ URL(string:$0)?.deletingPathExtension().lastPathComponent == String(fileIndex)}).first
        }
    }

    /**
     Returns the local path for media assets that have been bundled in your app's bundle for the passed in `Asset` or `AssetPersistable`.
     This only works if you've used the ContentfulBundleSync command line tool.

     - Parameter media: The Asset or AssetPersistable for which on-disk data should be retreived.
     - Parameter directory: The name of the directory in your bundle which contains the media data
     - Parameter bundle: The bundle in which your directory containing your media files is located.

     - Returns: The full string path for the underlying media file associated with the passed in `Asset` or `AssetPersistabl`. 
                Will return `nil` if no directory exists at your directory name, or if the `Media` does not have a valid `urlString` associated with it.
     */
    public static func pathInBundle(for media: Media, inDirectoryNamed directory: String, in bundle: Bundle) -> String? {
        let fileName = SynchronizationManager.fileName(for: media)
        return bundle.path(forResource: fileName, ofType: nil, inDirectory: directory)
    }

    /**
     Returns on-disk data that is bundled in your app's bundle for the passed in `Asset` or `AssetPersistable`.
     This only works if you've used the ContentfulBundleSync command line tool.
     
     - Parameter media: The Asset or AssetPersistable for which on-disk data should be retreived.
     - Parameter directory: The name of the directory in your bundle which contains the media data
     - Parameter bundle: The bundle in which your directory containing your media files is located.
     
     - Returns: The `Data` object for your media file. Will return `nil` if no directory exists at your directory name,
                or if the `Media` does not have a `urlString` associated with it.
     */
    public static func bundledData(for media: Media, inDirectoryNamed directory: String, in bundle: Bundle) -> Data? {
        guard let path = pathInBundle(for: media, inDirectoryNamed: directory, in: bundle) else { return nil }
        let data = FileManager.default.contents(atPath: path)
        return data
    }
    /**
     Returns a file name to be used for local storage given a passed in `Asset` or `AssetPersistable`.

     - Parameter media: The Asset or AssetPersistable for which a file name should be computed.
     
     - Returns: A filename for the underlying media file. Will return `nil` if the Asset or AssetPersistable
                does not have a `urlString` associated with it.
     */
    public static func fileName(for media: Media) -> String? {
        guard let urlString = media.urlString, let url = URL(string: urlString) else { return nil }
        let pathExtension = url.pathExtension.isEmpty ? "data" : url.pathExtension
        let fileName = "cache_" + media.id + "." + pathExtension
        return fileName
    }
    /**
     Errors thrown by ContentfulPersistence when trying to seed a database with bundled data.
     */
    public enum DatabaseSeedingError: Swift.Error, CustomDebugStringConvertible {

        /// Thrown if there is not valid JSON stored in the directory the libarary is trying to seed
        /// a database from.
        case invalidFilePath

        public var debugDescription: String {
            switch self {
            case .invalidFilePath:
                return "No JSON file's containing Contentful Sync data were found at the specified directory path"
            }
        }

    }
}
/**
 A simple protocol to bridge `Contentful.Asset` and `ContentfulPersistence.AssetPersistable` to enable
 consistent local storage patterns.
 */
public protocol Media {

    var id: String { get }
    var urlString: String? { get }
}

extension Contentful.Asset: Media {}
