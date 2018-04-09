//
//  Legend.h
//  SeattleParkingMap
//
//  Created by Marc on 12/24/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

// In the future this could be a AGSMapContentsLegendElement
@interface Legend : NSObject

@property (nonatomic) NSUInteger index;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) UIImage *image;

// These could be in an extension
@property (nonatomic) BOOL isBold;
@property (nonatomic) BOOL hasRoundedCorners;

@end
