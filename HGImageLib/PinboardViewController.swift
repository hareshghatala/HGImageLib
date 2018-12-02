//
//  PinboardViewController.swift
//  HGImageLib
//
//  Created by Haresh on 02/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import UIKit

class PinboardViewController: UIViewController {

    // MARK: Private Variables
    
    private static let collectionViewCellSpace: CGFloat = 2.0
    private static let collectionViewCellPerRowiPhone: CGFloat = 2.0
    private static let collectionViewCellMarginColumniPhone: CGFloat = 3.0
    private static let collectionViewCellPerRowiPad: CGFloat = 3.0
    private static let collectionViewCellMarginColumniPad: CGFloat = 4.0
    private static let dataURLString = "https://pastebin.com/raw/wgkJgazE"
    
    private lazy var placeholderImage = UIImage(named: "placeholder")!
    private lazy var imgURLs: [DataModel] = []
    private lazy var refresher: UIRefreshControl = UIRefreshControl()
    
    // MARK: Outlets

    @IBOutlet private weak var collectionView: UICollectionView! {
        didSet {
            self.refresher.addTarget(self, action: #selector(refreshData), for: .valueChanged)
            self.collectionView.addSubview(refresher)
        }
    }
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.getRequestAPICall()
    }
    
    private func getRequestAPICall()  {
        
        HGNetworkLib.performGet(with: type(of: self).dataURLString) { response, error in
            
            if let error = error {
                debugPrint(error.localizedDescription)
            } else if let data = response as? [[String : AnyObject]] {
                self.imgURLs.removeAll()
                
                for element in data {
                    guard let allUrls = element["urls"] as? [String: Any],
                        let regularUrl = allUrls["regular"] as? String else {
                            continue
                    }
                    
                    let dataModel = DataModel(imageURLString: regularUrl)
                    self.imgURLs.append(dataModel)
                }
            }
            
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.refresher.endRefreshing()
            }
        }
    }
    
    @objc private func refreshData() {
        getRequestAPICall()
    }
    
    fileprivate func sizeForCollectionViewItem() -> CGSize {
        let viewWidth = self.collectionView.bounds.size.width
        
        let selfType = type(of: self)
        var cellWidth: CGFloat = 0.0
        if UIDevice.current.userInterfaceIdiom == .phone {
            let margin = selfType.collectionViewCellMarginColumniPhone * selfType.collectionViewCellSpace
            cellWidth = (viewWidth - margin) / selfType.collectionViewCellPerRowiPhone
        } else {
            let margin = selfType.collectionViewCellMarginColumniPad * selfType.collectionViewCellSpace
            cellWidth = (viewWidth - margin) / selfType.collectionViewCellPerRowiPad
        }
        
        return CGSize(width: cellWidth, height: cellWidth)
    }
}

// MARK: - UICollectionView DataSource

extension PinboardViewController : UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imgURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCollectionViewCell.ReuseIdentifier, for: indexPath) as? ImageCollectionViewCell else {
            return UICollectionViewCell()
        }

        let dataModel = imgURLs[indexPath.row]
        cell.configureCell(with: dataModel.getURL(), placeholderImage: placeholderImage)

        return cell
    }
}

// MARK: - UICollectionView Delegate FlowLayout

extension PinboardViewController : UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return sizeForCollectionViewItem()
    }
    
}
