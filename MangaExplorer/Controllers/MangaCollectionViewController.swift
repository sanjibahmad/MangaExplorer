//
//  MangaCollectionViewController.swift
//  MangaExplorer
//
//  Created by Sanjib Ahmad on 9/5/15.
//  Copyright (c) 2015 Object Coder. All rights reserved.
//

/*
 * The MangaCollectionViewController class is utilized to show:
 *
 *   1. Top rated mangas,
 *   2. Manga genres.
 *
 * The public property genre: String? is utilized to determine whether top rated or manga genres should be shown.
 */

import UIKit
import CoreData

class MangaCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var collectionView: UICollectionView!
    
    let cellReuseIdentifier = "MangaCell"
    var genre: String?
    
    // Cell layout properties
    let cellsPerRowInPortraitMode: CGFloat = 3
    let cellsPerRowInLandscpaeMode: CGFloat = 5
    let minimumSpacingPerCell: CGFloat = 8
    
    // Core data
    let fetchBatchSize = 30
    
    private let photoPlaceholderImage = UIImage(named: "mangaPlaceholder")
    
    private var selectedIndexes = [NSIndexPath]()
    private var insertedIndexPaths: [NSIndexPath]!
    private var deletedIndexPaths: [NSIndexPath]!
    private var updatedIndexPaths: [NSIndexPath]!
    
    private var cache = NSCache()
    let backgroundQueue = dispatch_queue_create("MangaExplorerTopRated", DISPATCH_QUEUE_SERIAL)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        if let genre = genre {
            navigationItem.title = genre.capitalizedString
        } else {
            navigationItem.title = "Top Rated"
        }

        // CoreData
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            #if DEBUG
                NSLog("Perform fetch failed: \(error)")
            #endif
        }
        setMangaImagesInCacheForFirstFetchBatchSize()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "performFetchForFetchedResultsController", name: "performFetchForFetchedResultsControllerInTopRatedMangas", object: nil)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(true)
        
        // Set display max for top rated mangas
        if genre == nil {
            fetchedResultsController.fetchRequest.fetchLimit = UserDefaults.sharedInstance.topRatedMangasDisplayMax
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        
        // Init data if manga table is empty
        if UserDefaults.sharedInstance.didInitDatabase == false {            
            performSegueWithIdentifier("InitDataSegue", sender: self)
        } else {
            if UserDefaults.sharedInstance.shouldFetchLatestManga() {
                UserDefaults.sharedInstance.lastFetchedLatestManga = NSDate()
                AnimeNewsNetworkBatchUpdater.sharedInstance.updateWithLatestMangas()
            }
        }
    }
    
    // MARK: - NSCache
    
    private func setMangaImagesInCacheForFirstFetchBatchSize() {
        dispatch_async(backgroundQueue) {
            if self.fetchedResultsController.fetchedObjects?.count > 0 {
                var counter = 0
                for manga in self.fetchedResultsController.fetchedObjects as! [Manga] {
                    if let imageData = manga.imageData {
                        if let image = UIImage(data: imageData) {
                            self.cache.setObject(image, forKey: manga.imageName!)
                        }
                    }
                    counter++
                    if counter >= self.fetchBatchSize {
                        dispatch_async(dispatch_get_main_queue()) {
                            self.collectionView.reloadData()
                        }
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - CoreData
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let privateContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        privateContext.parentContext = self.sharedContext
        
        let fetchRequest = NSFetchRequest(entityName: "Manga")
        
        if let genre = self.genre {
            fetchRequest.predicate = NSPredicate(format: "ANY genre.name == %@", genre)
        } else {
            fetchRequest.fetchLimit = UserDefaults.sharedInstance.topRatedMangasDisplayMax
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "bayesianAverage", ascending: false)]
        fetchRequest.fetchBatchSize = self.fetchBatchSize
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: privateContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchedResultsController
    }()
    
    
    // For post notification from InitViewController or SettingsDisplayMaxTableViewController
    func performFetchForFetchedResultsController() {
        do {
            fetchedResultsController.fetchRequest.fetchLimit = UserDefaults.sharedInstance.topRatedMangasDisplayMax
            try fetchedResultsController.performFetch()
        } catch {
        }
        setMangaImagesInCacheForFirstFetchBatchSize()
        collectionView.reloadData()
    }
    
    // MARK: - Layout
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = minimumSpacingPerCell
        layout.minimumInteritemSpacing = minimumSpacingPerCell
        
        var cellWidth: CGFloat!
        
        // Landscape
        if UIApplication.sharedApplication().statusBarOrientation.isLandscape == true {
            let totalSpacingBetweenCells = (minimumSpacingPerCell * cellsPerRowInLandscpaeMode) - minimumSpacingPerCell
            let availableWidthForCells = collectionView.frame.size.width - totalSpacingBetweenCells
            cellWidth = availableWidthForCells / cellsPerRowInLandscpaeMode
            
        // Portrait
        } else {
            let totalSpacingBetweenCells = (minimumSpacingPerCell * cellsPerRowInPortraitMode) - minimumSpacingPerCell
            let availableWidthForCells = collectionView.frame.size.width - totalSpacingBetweenCells
            cellWidth = availableWidthForCells / cellsPerRowInPortraitMode
        }
        
        // Get 2 digit floored decimal point precision
        cellWidth = floor(cellWidth*100)/100
        
        // In storyboard, the manga image height:width ratio is specified as 1.3:1, 
        // 44 points is fixed space allocated to title and author labels
        layout.itemSize = CGSize(width: cellWidth, height: (cellWidth*1.3) + 44)
        collectionView.collectionViewLayout = layout
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        collectionView.performBatchUpdates(nil, completion: nil)
    }
    
    // MARK: - CollectionView delegates
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        selectedIndexes = [indexPath]
        performSegueWithIdentifier("MangaDetailsSegue", sender: self)
    }
    
    // MARK: - CollectionView data source
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] 
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellReuseIdentifier, forIndexPath: indexPath) as! MangaCollectionViewCell
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    // MARK: - Configure cell
    
    func configureCell(cell: MangaCollectionViewCell, atIndexPath indexPath: NSIndexPath) {
        let manga = fetchedResultsController.objectAtIndexPath(indexPath) as! Manga
        
        cell.titleLabel.text = manga.title
        
        var author = ""
        for staff in manga.staff {
            if author.isEmpty {
                author = staff.person
            } else {
                if staff.person == author {
                    continue
                }
                author = author + ", " + staff.person
            }            
        }
        cell.authorLabel.text = author
        
        if manga.bayesianAverage > 0 {
            cell.ratingsLabel.hidden = false
            
            // to round ratings to single digit precision, multiply by 10, round it, then divide by 10
            let ratings = Double(round(manga.bayesianAverage*10)/10)
            cell.ratingsLabel.text = "\(ratings)"
        } else {
            cell.ratingsLabel.hidden = true
        }
        
        // if imageName: check in cache, else check if already downloaded, else fetch
        if let imageName = manga.imageName {
            if let image = cache.objectForKey(imageName) as? UIImage {
                cell.mangaImageView.image = image
                cell.activityIndicator.stopAnimating()
            } else {
                if let imageData = manga.imageData {
                    let image = UIImage(data: imageData)!
                    cache.setObject(image, forKey: imageName)
                    cell.mangaImageView.image = image
                    cell.activityIndicator.stopAnimating()
                } else {
                    cell.mangaImageView.image = photoPlaceholderImage
                    cell.activityIndicator.startAnimating()
                    if !manga.fetchInProgress {
                        manga.fetchImageData { fetchComplete in
                            if fetchComplete {
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.safeReloadAtIndexPath(indexPath)
                                    NSNotificationCenter.defaultCenter().postNotificationName("refreshMangaImageNotification", object: nil)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            cell.mangaImageView.image = photoPlaceholderImage
            cell.activityIndicator.stopAnimating()
        }
    }
    
    func safeReloadAtIndexPath(indexPath: NSIndexPath) {
        if let fetchedObjectsCount = fetchedResultsController.fetchedObjects?.count {
            if fetchedObjectsCount >= indexPath.row {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
        }
    }
    
    // MARK: - NSFetchedResultsController delegates
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            insertedIndexPaths.append(newIndexPath!)
        case .Delete:
            deletedIndexPaths.append(indexPath!)
        case .Update:
            updatedIndexPaths.append(indexPath!)
        default:
            return
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        collectionView.performBatchUpdates({
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
        }, completion: nil)
    }
    
    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "MangaDetailsSegue" {
            let vc = segue.destinationViewController as! MangaDetailsTableViewController
            let manga = fetchedResultsController.objectAtIndexPath(selectedIndexes.first!) as! Manga
            vc.mangaId = manga.id
        }
    }

}
