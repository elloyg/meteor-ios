// Copyright (c) 2014 Martijn Walraven
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import CoreData

// Needed to support enumeration
extension NSHashTable: SequenceType {
  public func generate() -> NSFastGenerator {
    return NSFastGenerator(self)
  }
}

public enum FetchedResultsChangeDetail {
  case SectionInserted(Int)
  case SectionDeleted(Int)
  case ObjectInserted(NSIndexPath)
  case ObjectDeleted(NSIndexPath)
  case ObjectUpdated(NSIndexPath)
  case ObjectMoved(indexPath: NSIndexPath, newIndexPath: NSIndexPath)
}

public class FetchedResultsChanges: NSObject {
  private(set) var changeDetails = [FetchedResultsChangeDetail]()
  
  func addChangeDetail(changeDetail: FetchedResultsChangeDetail) {
    changeDetails.append(changeDetail)
  }
}

@objc public protocol FetchedResultsChangeObserver: NSObjectProtocol {
  func fetchedResultsDidLoad(fetchedResult: FetchedResults)
  func fetchedResults(fetchedResult: FetchedResults, didFailWithError error: NSError)
  func fetchedResults(fetchedResult: FetchedResults, didChange changes: FetchedResultsChanges)
}

public class FetchedResults: NSObject, NSFetchedResultsControllerDelegate {
  // Class should be generic but that isn't possible right know due to limitations of associated types needed for the observer protocol
  public typealias T = NSManagedObject
  
  private var fetchedResultsController: NSFetchedResultsController
  private var observers: NSHashTable
  private var changes: FetchedResultsChanges?
  
  init(managedObjectContext: NSManagedObjectContext, fetchRequest: NSFetchRequest) {
    fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
    observers = NSHashTable.weakObjectsHashTable()
    super.init()
    fetchedResultsController.delegate = self
  }
  
  // MARK: - Change Observers
  
  func registerChangeObserver(observer: FetchedResultsChangeObserver) {
    observers.addObject(observer)
  }
  
  func unregisterChangeObserver(observer: FetchedResultsChangeObserver) {
    observers.removeObject(observer)
  }
  
  func notifyDidLoad() {
    for observer in observers {
      (observer as FetchedResultsChangeObserver).fetchedResultsDidLoad(self)
    }
  }
  
  func notifyDidFailWithError(error: NSError) {
    for observer in observers {
      (observer as FetchedResultsChangeObserver).fetchedResults(self, didFailWithError: error)
    }
  }
  
  func notifyDidChange(changes: FetchedResultsChanges) {
    for observer in observers {
      (observer as FetchedResultsChangeObserver).fetchedResults(self, didChange: changes)
    }
  }
  
  // MARK: - Fetching
  
  func performFetch() {
    var error: NSError?
    if fetchedResultsController.performFetch(&error) {
      notifyDidLoad()
    } else if error != nil {
      notifyDidFailWithError(error!)
    }
  }
  
  public var numberOfSections: Int {
    return fetchedResultsController.sections?.count ?? 0
  }
  
  public func numberOfItemsInSection(section: Int) -> Int {
    let sectionInfo = fetchedResultsController.sections?[section] as NSFetchedResultsSectionInfo
    return sectionInfo.numberOfObjects ?? 0
  }
  
  public func objectAtIndexPath(indexPath: NSIndexPath) -> T {
    return fetchedResultsController.objectAtIndexPath(indexPath) as T
  }
  
  // MARK: - NSFetchedResultsControllerDelegate

  public func controllerWillChangeContent(controller: NSFetchedResultsController!) {
    changes = FetchedResultsChanges()
  }
  
  public func controller(controller: NSFetchedResultsController!, didChangeSection sectionInfo: NSFetchedResultsSectionInfo!, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
    switch(type) {
    case .Insert:
      changes!.addChangeDetail(.SectionInserted(sectionIndex))
    case .Delete:
      changes!.addChangeDetail(.SectionDeleted(sectionIndex))
    default:
      break
    }
  }
  
  public func controller(controller: NSFetchedResultsController!, didChangeObject object: AnyObject!, atIndexPath indexPath: NSIndexPath!, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath!) {
    switch(type) {
    case .Insert:
      changes!.addChangeDetail(.ObjectInserted(newIndexPath))
    case .Delete:
      changes!.addChangeDetail(.ObjectDeleted(indexPath))
    case .Update:
      changes!.addChangeDetail(.ObjectUpdated(indexPath))
    case .Move:
      changes!.addChangeDetail(.ObjectMoved(indexPath: indexPath, newIndexPath: newIndexPath))
    default:
      break
    }
  }

  public func controllerDidChangeContent(controller: NSFetchedResultsController) {
    notifyDidChange(changes!)
    changes = nil
  }
}
