//
//  ParkingSpotCalloutView.h
//  SeattleParkingMap
//
//  Created by Marc on 12/19/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@interface ParkingSpotCalloutView : UIView

@property (weak, nonatomic) IBOutlet UILabel *labelTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelSubtitle;

@property (nonatomic, weak, readonly) UIView *popoverSourceView;

@property (nullable, copy, nonatomic) dispatch_block_t timeBlock;
@property (nullable, copy, nonatomic) dispatch_block_t dismissBlock;

@end

NS_ASSUME_NONNULL_END
