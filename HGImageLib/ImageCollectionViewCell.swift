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
        
        self.imageView.hg_cancelImageRequest()
        self.imageView.layer.removeAllAnimations()
        self.imageView.image = nil
    }
    
    // MARK: - Helper methods
    
    func configureCell(with imgURL: URL, placeholderImage: UIImage) {
        self.imageView.hg_setImage(withURL: imgURL,
                                   placeholderImage: placeholderImage,
                                   imageTransition: .flipFromLeft(0.4))
    }
}
