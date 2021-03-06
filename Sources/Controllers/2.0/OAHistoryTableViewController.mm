//
//  OAHistoryTableViewController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 17/12/2016.
//  Copyright © 2016 OsmAnd. All rights reserved.
//

#import "OAHistoryTableViewController.h"
#import "OAPOISearchHelper.h"
#import "OsmAndApp.h"
#import <CoreLocation/CoreLocation.h>
#import "OAHistoryItem.h"
#import "OAMultiselectableHeaderView.h"
#import "OAHistoryHelper.h"
#import "Localization.h"
#import "OAPointDescCell.h"
#import "OAUtilities.h"

#include <OsmAndCore/Utilities.h>


@interface SearchHistoryTableItem : NSObject

@property (nonatomic) OAHistoryItem *item;
@property (nonatomic, assign) CGFloat distanceMeters;
@property (nonatomic) NSString *distance;
@property (nonatomic, assign) CGFloat direction;

@end

@implementation SearchHistoryTableItem

@end


@interface SearchHistoryTableGroup : NSObject

@property NSString *groupName;
@property NSMutableArray *groupItems;

@end

@implementation SearchHistoryTableGroup

- (id)init
{
    self = [super init];
    if (self)
    {
        self.groupItems = [NSMutableArray array];
    }
    return self;
}

-(BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    
    SearchHistoryTableGroup *item = object;
    
    return [self.groupName isEqualToString:item.groupName];
}

-(NSUInteger)hash
{
    return [self.groupName hash];
}

@end


@interface OAHistoryTableViewController () <OAMultiselectableHeaderDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate>

@property (strong, nonatomic) NSMutableArray* groupsAndItems;

@end

@implementation OAHistoryTableViewController
{
    BOOL isDecelerating;
    NSArray *_headerViews;
    BOOL _wasAnyDeleted;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [[OAHistoryTableViewController alloc] initWithNibName:@"OAHistoryTableViewController" bundle:nil];
    if (self)
    {
        self.view.frame = frame;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longTapHandler:)];
    longPressGesture.delegate = self;
    [self.tableView addGestureRecognizer:longPressGesture];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    isDecelerating = NO;
}

-(void) longTapHandler:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (![self.tableView isEditing])
    {
        _wasAnyDeleted = NO;
        
        CGPoint p = [gestureRecognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
        
        if (self.delegate)
            [self.delegate enterHistoryEditingMode];
        
        [self.tableView beginUpdates];
        [self.tableView setEditing:YES animated:YES];
        if (indexPath && gestureRecognizer.state == UIGestureRecognizerStateBegan)
        {
            [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
            if (self.delegate)
                [self.delegate historyItemsSelected:1];
        }

        [self.tableView endUpdates];
        }
}

- (void)editDone
{
    [self.tableView beginUpdates];
    [self.tableView setEditing:NO animated:YES];
    [self.tableView endUpdates];
    
    if (_wasAnyDeleted)
    {
        _wasAnyDeleted = NO;
        [self generateData];
        [self updateDistanceAndDirection];
    }
}

-(void)reloadData
{
    [self generateData];
    if (self.groupsAndItems.count > 0)
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    [self updateDistanceAndDirection];
}

- (NSTimeInterval)beginningOfToday
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *components = [cal components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate date]];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    [components setNanosecond:0];
    NSDate *today = [cal dateFromComponents:components];
    
    return [today timeIntervalSince1970];
}

-(void)generateData
{
    [self generateData:YES];
}

-(void)generateData:(BOOL)doReload
{
    self.groupsAndItems = [[NSMutableArray alloc] init];
    NSMutableArray *headerViews = [NSMutableArray array];
    
    OAHistoryHelper *helper = [OAHistoryHelper sharedInstance];
    NSArray *allItems = [helper getPointsHavingTypes:helper.searchTypes limit:0];
    
    NSTimeInterval todayBeginTime = [self beginningOfToday];
    NSTimeInterval yesterdayBeginTime = todayBeginTime - 60 * 60 * 24;
    
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"LLLL - yyyy"];
    
    for (OAHistoryItem *item in allItems)
    {
        NSString *groupName;
        NSTimeInterval time = [item.date timeIntervalSince1970];
        if (time < yesterdayBeginTime)
        {
            groupName = [fmt stringFromDate:item.date];
        }
        else if (time < todayBeginTime)
        {
            groupName = @"1";
        }
        else
        {
            groupName = @"0";
        }
        
        SearchHistoryTableGroup *grp;
        for (SearchHistoryTableGroup *g in self.groupsAndItems)
            if ([g.groupName isEqualToString:groupName])
            {
                grp = g;
                break;
            }
        
        if (!grp)
        {
            grp = [[SearchHistoryTableGroup alloc] init];
            grp.groupName = groupName;
            [self.groupsAndItems addObject:grp];
        }
        
        SearchHistoryTableItem *tableItem = [[SearchHistoryTableItem alloc] init];
        tableItem.item = item;
        [grp.groupItems addObject:tableItem];
    }
    
    // Sort items
    NSArray *sortedArrayGroups = [self.groupsAndItems sortedArrayUsingComparator:^NSComparisonResult(SearchHistoryTableGroup* obj1, SearchHistoryTableGroup* obj2) {
        return [obj1.groupName localizedCaseInsensitiveCompare:obj2.groupName];
    }];
    [self.groupsAndItems setArray:sortedArrayGroups];
    
    int i = 0;
    for (SearchHistoryTableGroup *group in self.groupsAndItems)
    {
        // add header
        OAMultiselectableHeaderView *headerView = [[OAMultiselectableHeaderView alloc] initWithFrame:CGRectMake(0.0, 1.0, 100.0, 44.0)];
        if ([group.groupName isEqualToString:@"0"])
            [headerView setTitleText:OALocalizedString(@"today")];
        else if ([group.groupName isEqualToString:@"1"])
            [headerView setTitleText:OALocalizedString(@"yesterday")];
        else
            [headerView setTitleText:group.groupName];
        
        headerView.section = i++;
        headerView.delegate = self;
        [headerViews addObject:headerView];
    }
    
    if (doReload)
        [self.tableView reloadData];
    
    _headerViews = [NSArray arrayWithArray:headerViews];
}

- (void)updateDistanceAndDirection
{
    if ([self.tableView isEditing])
        return;
    
    OsmAndAppInstance app = [OsmAndApp instance];
    // Obtain fresh location and heading
    CLLocation* newLocation = app.locationServices.lastKnownLocation;
    if (_searchNearMapCenter)
    {
        OsmAnd::LatLon latLon = OsmAnd::Utilities::convert31ToLatLon(_myLocation);
        newLocation = [[CLLocation alloc] initWithLatitude:latLon.latitude longitude:latLon.longitude];
    }
    if (!newLocation)
        return;
    
    CLLocationDirection newHeading = app.locationServices.lastKnownHeading;
    CLLocationDirection newDirection =
    (newLocation.speed >= 1 /* 3.7 km/h */ && newLocation.course >= 0.0f)
    ? newLocation.course
    : newHeading;
    
    for (SearchHistoryTableGroup *group in self.groupsAndItems)
    {
        for (SearchHistoryTableItem *dataItem in group.groupItems)
        {
            const auto distance = OsmAnd::Utilities::distance(newLocation.coordinate.longitude,
                                                              newLocation.coordinate.latitude,
                                                              dataItem.item.longitude, dataItem.item.latitude);
            
            dataItem.distance = [app getFormattedDistance:distance];
            dataItem.distanceMeters = distance;
            CGFloat itemDirection = [app.locationServices radiusFromBearingToLocation:[[CLLocation alloc] initWithLatitude:dataItem.item.latitude longitude:dataItem.item.longitude]];
            dataItem.direction = OsmAnd::Utilities::normalizedAngleDegrees(itemDirection - newDirection) * (M_PI / 180);
        }
    }
    
    if (isDecelerating)
        return;
    
    [self refreshVisibleRows];
}

- (void)refreshVisibleRows
{
    if ([self.tableView isEditing])
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.tableView beginUpdates];
        NSArray *visibleIndexPaths = [self.tableView indexPathsForVisibleRows];
        for (NSIndexPath *i in visibleIndexPaths)
        {
            OAPointDescCell *cell = (OAPointDescCell *)[self.tableView cellForRowAtIndexPath:i];
            SearchHistoryTableGroup *groupData = [self.groupsAndItems objectAtIndex:i.section];
            SearchHistoryTableItem *dataItem = [groupData.groupItems objectAtIndex:i.row];
            [self updateCell:cell dataItem:dataItem];
        }
        [self.tableView endUpdates];
    });
}

- (void)deleteSelected
{
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    if ([selectedRows count] == 0) {
        UIAlertView* removeAlert = [[UIAlertView alloc] initWithTitle:@"" message:OALocalizedString(@"hist_select_remove") delegate:nil cancelButtonTitle:OALocalizedString(@"shared_string_ok") otherButtonTitles:nil];
        [removeAlert show];
        return;
    }
    
    UIAlertView* removeAlert = [[UIAlertView alloc] initWithTitle:@"" message:OALocalizedString(@"hist_remove_q") delegate:self cancelButtonTitle:OALocalizedString(@"shared_string_no") otherButtonTitles:OALocalizedString(@"shared_string_yes"), nil];
    [removeAlert show];
}

-(NSArray*)getItemsForRows:(NSArray*)indexPath
{
    NSMutableArray* itemList = [[NSMutableArray alloc] init];
    
    [indexPath enumerateObjectsUsingBlock:^(NSIndexPath* path, NSUInteger idx, BOOL *stop) {
        SearchHistoryTableGroup* groupData = [self.groupsAndItems objectAtIndex:path.section];
        [itemList addObject:[groupData.groupItems objectAtIndex:path.row]];
    }];
    
    return itemList;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex)
    {
        NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
        NSArray* selectedItems = [self getItemsForRows:selectedRows];
        
        NSMutableArray *arr = [NSMutableArray array];
        for (SearchHistoryTableItem* dataItem in selectedItems)
            [arr addObject:dataItem.item];
        
        [[OAHistoryHelper sharedInstance] removePoints:arr];
        
        _wasAnyDeleted = YES;
        
        if (self.delegate)
        {
            [self editDone];
            [self.delegate exitHistoryEditingMode];
        }
    }
}

#pragma mark - OAMultiselectableHeaderDelegate

-(void)headerCheckboxChanged:(id)sender value:(BOOL)value
{
    OAMultiselectableHeaderView *headerView = (OAMultiselectableHeaderView *)sender;
    NSInteger section = headerView.section;
    NSInteger rowsCount = [self.tableView numberOfRowsInSection:section];
    
    [self.tableView beginUpdates];
    if (value)
    {
        for (int i = 0; i < rowsCount; i++)
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:section] animated:YES scrollPosition:UITableViewScrollPositionNone];
    }
    else
    {
        for (int i = 0; i < rowsCount; i++)
            [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:section] animated:YES];
    }
    [self.tableView endUpdates];

    if (self.delegate && self.tableView.editing)
        [self.delegate historyItemsSelected:(int)([self.tableView indexPathsForSelectedRows].count)];
}

- (void)updateCell:(OAPointDescCell *)cell dataItem:(SearchHistoryTableItem *)dataItem
{
    [cell.titleView setText:dataItem.item.name];
    cell.titleIcon.image = [dataItem.item icon];
    [cell.descView setText:dataItem.item.typeName.length > 0 ? dataItem.item.typeName : OALocalizedString(@"history")];
    [cell updateDescVisibility];
    cell.openingHoursView.hidden = YES;
    cell.timeIcon.hidden = YES;
    
    [cell.distanceView setText:dataItem.distance];
    if (_searchNearMapCenter)
    {
        cell.directionImageView.hidden = YES;
        CGRect frame = cell.distanceView.frame;
        frame.origin.x = 51.0;
        cell.distanceView.frame = frame;
    }
    else
    {
        cell.directionImageView.hidden = NO;
        CGRect frame = cell.distanceView.frame;
        frame.origin.x = 69.0;
        cell.distanceView.frame = frame;
        cell.directionImageView.transform = CGAffineTransformMakeRotation(dataItem.direction);
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.groupsAndItems count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SearchHistoryTableGroup* groupData = [self.groupsAndItems objectAtIndex:indexPath.section];
    SearchHistoryTableItem* dataItem = [groupData.groupItems objectAtIndex:indexPath.row];
    CGSize size = [OAUtilities calculateTextBounds:dataItem.item.name width:tableView.bounds.size.width - 59.0 font:[UIFont fontWithName:@"AvenirNext-Regular" size:14.0]];
    
    return 30.0 + size.height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 46.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == tableView.numberOfSections - 1)
        return [OAPOISearchHelper getHeightForFooter];
    else
        return 0.01;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return _headerViews[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [((SearchHistoryTableGroup*)[self.groupsAndItems objectAtIndex:section]).groupItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SearchHistoryTableGroup* groupData = [self.groupsAndItems objectAtIndex:indexPath.section];
    
    static NSString* const reusableIdentifierPoint = @"OAPointDescCell";
    
    OAPointDescCell* cell;
    cell = (OAPointDescCell *)[self.tableView dequeueReusableCellWithIdentifier:reusableIdentifierPoint];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OAPointDescCell" owner:self options:nil];
        cell = (OAPointDescCell *)[nib objectAtIndex:0];
    }
    
    if (cell)
    {
        SearchHistoryTableItem* dataItem = [groupData.groupItems objectAtIndex:indexPath.row];
        [self updateCell:cell dataItem:dataItem];
    }
    
    return cell;
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.delegate)
    {
        if (tableView.editing)
        {
            [self.delegate historyItemsSelected:(int)([tableView indexPathsForSelectedRows].count)];
        }
        else
        {
            SearchHistoryTableGroup* groupData = [self.groupsAndItems objectAtIndex:indexPath.section];
            SearchHistoryTableItem* dataItem = [groupData.groupItems objectAtIndex:indexPath.row];
            [self.delegate didSelectHistoryItem:dataItem.item];
        }
    }
}

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.delegate && tableView.editing)
        [self.delegate historyItemsSelected:(int)([tableView indexPathsForSelectedRows].count)];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    isDecelerating = YES;
}

// Load images for all onscreen rows when scrolling is finished
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
        isDecelerating = NO;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    isDecelerating = NO;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return !self.tableView.editing;
}

@end
