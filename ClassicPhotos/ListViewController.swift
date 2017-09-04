//
//  ListViewController.swift
//  ClassicPhotos
//
//  Created by neal on 2017/9/1.
//  Copyright © 2017年 neal. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceURL = URL(string: "http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ListViewController: UITableViewController {

    var photos = [PhotoRecord]()
    let pendingOperations = PendingOperations()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Classic Photos"
        
        fetchPhotoDetails()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - 获取图片

    fileprivate func fetchPhotoDetails() {

        let request = URLRequest(url: dataSourceURL!)
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        NSURLConnection.sendAsynchronousRequest(request, queue: OperationQueue.main) { (response, data, error) in
            if let error = error {
                let alert = UIAlertController.init(title: "Oops!", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "知道了", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            
            if let data = data {
                do {
                    if let datsourceDictonary = try PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.ReadOptions(rawValue: 0), format: nil) as? [String: AnyObject] {
                        
                        for (name,url) in datsourceDictonary {
                            if let url = URL(string: url as! String) {
                                let photoRecord = PhotoRecord(name:name,url:url)
                                self.photos.append(photoRecord)
                            }
                        }
                        self.tableView.reloadData()
                    }
                } catch let error as NSError {
                    print(error.domain)
                }
            }
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = false

        }
       
    }
    
    fileprivate func startOperationsForPhotoRecord(photoDetails: PhotoRecord, indexPath: IndexPath) {
        switch photoDetails.state {
        case .New:
            startDownloadForRecord(photoDetails: photoDetails, indexPath: indexPath)
        case .Downloaded:
            startFilterationForRecord(photoDetails: photoDetails, indexPath: indexPath)
        default:
            print("do nothing")
        }
    }

    fileprivate func startDownloadForRecord(photoDetails:PhotoRecord,indexPath: IndexPath) {
        if let _ = pendingOperations.downloadsInProgres[indexPath] {
            return
        }
        
        let  downloader = ImageDownloader(photoRecord: photoDetails)
        
        downloader.completionBlock = {
            if  downloader.isCancelled {
                return
            }
            
            DispatchQueue.main.async {
                self.pendingOperations.downloadsInProgres.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        
        pendingOperations.downloadsInProgres[indexPath] = downloader
        pendingOperations.downloadQueue.addOperation(downloader)
    }
    
    
    func startFilterationForRecord(photoDetails: PhotoRecord, indexPath: IndexPath) {
        if let _ = pendingOperations.filtrationsInProgress[indexPath] {
            return
        }
        
        let filterer = ImageFiltration(photoRecord: photoDetails)
        filterer.completionBlock = {
            if filterer.isCancelled {
                return
            }
            
            DispatchQueue.main.async {
                self.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        
        pendingOperations.filtrationsInProgress[indexPath] = filterer
        pendingOperations.filtrationQueue.addOperation(filterer)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return photos.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
        
        if cell.accessoryView == nil {
            let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            cell.accessoryView = indicator
            
        }
        let indicator = cell.accessoryView as! UIActivityIndicatorView
        
        let photoDetails = photos[indexPath.row]
        
        cell.textLabel?.text = photoDetails.name
        cell.imageView?.image = photoDetails.image
        
        switch photoDetails.state {
        case .Filtered,.Failed:
            indicator.stopAnimating()
        case .New, .Downloaded:
            indicator.startAnimating()
            if !tableView.isDragging && !tableView.isDecelerating {
                self.startOperationsForPhotoRecord(photoDetails: photoDetails, indexPath: indexPath)
            }
        }
        return cell
    }
    
    // MARK: - scrollviewDelegate

    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        suspendAllOperations()
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            loadImagesForOnscreenCells()
            resumeAllOperations()
        }
   
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        loadImagesForOnscreenCells()
        resumeAllOperations()
    }
    
    fileprivate func suspendAllOperations() {
        pendingOperations.downloadQueue.isSuspended = true
        pendingOperations.filtrationQueue.isSuspended = true
    }
    
    fileprivate func resumeAllOperations() {
        pendingOperations.downloadQueue.isSuspended = false
        pendingOperations.filtrationQueue.isSuspended = false
    }
    
    func loadImagesForOnscreenCells() {
        if let pathsArray = tableView.indexPathsForVisibleRows {
            var allPendingOperations = Set(pendingOperations.downloadsInProgres.keys)
            allPendingOperations = allPendingOperations.union(pendingOperations.filtrationsInProgress.keys)
            
            var toBeCancelled = allPendingOperations
            let visiblePaths = Set(pathsArray)
            toBeCancelled.subtract(visiblePaths)
            
            
            var toBeStarted = visiblePaths
            toBeStarted.subtract(allPendingOperations)
            
            for indexPath in toBeCancelled {
                if let pendingDownload = pendingOperations.downloadsInProgres[indexPath] {
                    pendingDownload.cancel()
                }
                
                pendingOperations.downloadsInProgres.removeValue(forKey: indexPath)
                if let pendingFilration = pendingOperations.filtrationsInProgress[indexPath] {
                    pendingFilration.cancel()
                }
                pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
            }
            
            for indexPath in toBeStarted {
                
                let recordToProcess = self.photos[indexPath.row]
                startOperationsForPhotoRecord(photoDetails: recordToProcess, indexPath: indexPath)
            }
        }
    }
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
