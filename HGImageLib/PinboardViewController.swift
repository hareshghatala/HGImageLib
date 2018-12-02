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
    
    private lazy var imgURLs: [String] = ["https://images.unsplash.com/photo-1464550883968-cec281c19761",
                                          "https://images.unsplash.com/photo-1464550838636-1a3496df938b",
                                          "https://images.unsplash.com/photo-1464537356976-89e35dfa63ee",
                                          "https://images.unsplash.com/photo-1464550883968-cec281c19761",
                                          "https://images.unsplash.com/photo-1464550838636-1a3496df938b",
                                          "https://images.unsplash.com/photo-1464537356976-89e35dfa63ee",
                                          "https://images.unsplash.com/photo-1464550883968-cec281c19761",
                                          "https://images.unsplash.com/photo-1464550838636-1a3496df938b",
                                          "https://images.unsplash.com/photo-1464537356976-89e35dfa63ee"]
    private lazy var placeholderImage = UIImage(named: "placeholder")!
    private static let collectionViewCellSpace: CGFloat = 2.0
    private static let collectionViewCellPerRowiPhone: CGFloat = 2.0
    private static let collectionViewCellMarginColumniPhone: CGFloat = 3.0
    private static let collectionViewCellPerRowiPad: CGFloat = 3.0
    private static let collectionViewCellMarginColumniPad: CGFloat = 4.0
    
    // MARK: Outlets

    @IBOutlet private weak var collectionView: UICollectionView!
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        
        debugPrint("Size: \(cellWidth):\(cellWidth)")
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

        let imgUrlString = imgURLs[indexPath.row]
        cell.configureCell(with: imgUrlString, placeholderImage: placeholderImage)

        return cell
    }
}

// MARK: - UICollectionView Delegate FlowLayout

extension PinboardViewController : UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return sizeForCollectionViewItem()
    }
    
}
