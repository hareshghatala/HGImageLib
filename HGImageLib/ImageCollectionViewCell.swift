//
//  ImageCollectionViewCell.swift
//  HGImageLib
//
//  Created by Haresh on 02/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import UIKit

class ImageCollectionViewCell: UICollectionViewCell {
    
    // MARK: - Constants
    
    static let ReuseIdentifier = "ImageCellIdentifier"
    
    // MARK: - Outlet
    
    @IBOutlet private weak var imageView: UIImageView!
    
    // MARK: - Lifecycle Methods
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // cancel async image loading
        self.imageView.layer.removeAllAnimations()
        self.imageView.image = nil
    }
    
    // MARK: - Helper methods
    
    func configureCell(with URLString: String, placeholderImage: UIImage) {
        self.imageView.image = placeholderImage
//
//        guard let imgUrl = URL(string: URLString) else {
//            self.imageView.image = placeholderImage
//            return
//        }
        
        // code to async image loading
    }
}
