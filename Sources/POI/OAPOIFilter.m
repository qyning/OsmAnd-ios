//
//  OAPOIFilter.m
//  OsmAnd
//
//  Created by Alexey Kulish on 29/03/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAPOIFilter.h"
#import "OAUtilities.h"

@implementation OAPOIFilter

- (instancetype)initWithName:(NSString *)name category:(OAPOICategory *)category;
{
    self = [super initWithName:name];
    if (self)
    {
        _category = category;
    }
    return self;
}

- (UIImage *)icon
{
    UIImage *img = [super icon];
    if (!img)
    {
        img = [UIImage imageNamed:[NSString stringWithFormat:@"style-icons/drawable-%@/mx_%@", [OAUtilities drawablePostfix], self.category.name]];
        return [OAUtilities applyScaleFactorToImage:img];
    }
    return img;
}

-(BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[OAPOIFilter class]])
    {
        OAPOIFilter *obj = object;
        return [self.name isEqualToString:obj.name];
    }
    return NO;
}

-(NSUInteger)hash
{
    return [self.name hash] + (self.category ? [self.category hash] : 1);
}

- (void)addPoiType:(OAPOIType *)poiType
{
    if (!_poiTypes)
    {
        _poiTypes = @[poiType];
    }
    else
    {
        _poiTypes = [_poiTypes arrayByAddingObject:poiType];
    }
}

@end
