//
//  LegendTableViewCell.h
//  SeattleParkingMap
//
//  Created by Marc on 12/24/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@class Legend;

@interface LegendTableViewCell : UITableViewCell

@property (nonatomic, weak) Legend *legend;
@property (weak, nonatomic) IBOutlet UILabel *legendLabel;

@end
