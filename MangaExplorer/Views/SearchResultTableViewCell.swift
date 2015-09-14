//
//  SearchResultTableViewCell.swift
//  MangaExplorer
//
//  Created by Sanjib Ahmad on 9/14/15.
//  Copyright (c) 2015 Object Coder. All rights reserved.
//

import UIKit

class SearchResultTableViewCell: UITableViewCell {
    @IBOutlet weak var mangaImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var alternativeTitlesLabel: UILabel!
    @IBOutlet weak var creatorsLabel: UILabel!

    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        let backgroundView = UIView(frame: frame)
        backgroundView.backgroundColor = UIColor.blackColor()
        selectedBackgroundView = backgroundView
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
