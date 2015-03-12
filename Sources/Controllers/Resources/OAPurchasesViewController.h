//
//  OAPurchasesViewController.h
//  OsmAnd
//
//  Created by Alexey Kulish on 06/03/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OASuperViewController.h"

@interface OAPurchasesViewController : OASuperViewController

@property (weak, nonatomic) IBOutlet UIView *toolbarView;
@property (weak, nonatomic) IBOutlet UIButton *btnToolbarMaps;
@property (weak, nonatomic) IBOutlet UIButton *btnToolbarPurchases;

@property (nonatomic, assign) BOOL openFromSplash;

@end