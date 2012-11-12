//
//  FlipsideViewController.m
//  Weather
//
//  Created by Eugene Scherba on 1/11/11.
//  Copyright 2011 Boston University. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "WeatherAppDelegate.h"
#import "FlipsideViewController.h"
#import "RSAddGeo.h"
#import "JSONKit.h"

@implementation FlipsideViewController

@synthesize addCity;
@synthesize delegate;

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor viewFlipsideBackgroundColor];
    if (!appDelegate) {
        appDelegate = (WeatherAppDelegate *) [[UIApplication sharedApplication] delegate];
    }
    //toggleSwitch.on = [[appDelegate.defaults objectForKey:@"checkLocation"] boolValue];
    
    // add City view controller
    geoAddController = [[RSAddGeo alloc] initWithNibName:@"RSAddGeo" bundle:nil];
    geoAddController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    geoAddController.delegate = self;

    // initialize model dictionary by using model array in the delegate object
    modelDict = [[NSMutableDictionary alloc] init];
    NSMutableArray *arr = self.delegate.modelArray;
    for (RSLocality* locality in arr) {
        [modelDict setObject:locality forKey:[locality apiId]];
    }

    _tableView.dataSource = self;
    _tableView.delegate = self;
    [_tableView setEditing:YES animated:NO];
    [self.view addSubview:_tableView];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/
- (void)dealloc
{
    // private variables
    [theURL release];
    [apiConnection release];
    [responseData release];
    [modelDict release];
    [theURL release];
    
    [geoAddController release];
    [_tableView release];

    [super dealloc];
}

#pragma mark - Internals
- (void)geoAddControllerDidFinish:(RSAddGeo *)controller
{
    // capture controller.selectedLocation
    RSLocality* selectedLocality = controller.selectedLocality;
    if (!selectedLocality) {
        // simply dismiss view controller and exit
        [responseData release];
        responseData = [[NSMutableData data] retain];
        
        //[self dismissModalViewControllerAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    // We keep _currentLocalityId as a temporary variable to be reused when
    // the new connection finishes
    _currentLocalityId = [selectedLocality apiId];
    RSLocality* currentLocality = [modelDict objectForKey:_currentLocalityId];
    if (currentLocality) {
        [currentLocality updateFrom:selectedLocality];
    } else {

        // if locality id not in the dictionary,
        // append it there as well as to the array
        [modelDict setObject:selectedLocality forKey:_currentLocalityId];
        [self.delegate.modelArray addObject:selectedLocality];
        [self.delegate addPageWithLocality:selectedLocality];
        currentLocality = selectedLocality;
        
        NSArray *paths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:[_tableView numberOfRowsInSection:1] inSection:1]];
        [_tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationTop];
        [_tableView reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
    }

    [responseData release];
    responseData = [[NSMutableData data] retain];

    if (!currentLocality.haveCoord) {
        // Perform a details request to get Latitude and Longitude data
        theURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/details/json?reference=%@&sensor=true&key=AIzaSyAU8uU4oGLZ7eTEazAf9pOr3qnYVzaYTCc", [currentLocality reference]]];
        apiConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:theURL] delegate:self startImmediately: YES];
    }
    
	//[self dismissModalViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - actions

- (void) switchChanged:(id)sender {
    UISwitch* switchControl = sender;
    NSLog( @"The switch is %@", switchControl.on ? @"ON" : @"OFF" );
    //    if (toggleSwitch.on) {
    //        [appDelegate.locationManager startUpdatingLocation];
    //    } else {
    //        [appDelegate.locationManager stopUpdatingLocation];
    //    }
}

- (IBAction)done:(id)sender {
    //[appDelegate.defaults setObject:[NSNumber numberWithBool:toggleSwitch.on] forKey:@"checkLocation"];
	[self.delegate flipsideViewControllerDidFinish:self];	
}

- (IBAction)addCityTouchDown {
    // with animated:NO, the view loads a bit faster
    [self presentViewController:geoAddController animated:NO completion:nil];
}

#pragma mark - UITableViewDelegate methods

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    if (section == 0) {
        // first section only displays switch to toggle location tracking
        return 1;
    } else {
        return [self.delegate.modelArray count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    RSLocality *locality;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell.accessoryType = UITableViewCellAccessoryNone;
        switch(indexPath.section) {
            case 0:
                // Current location
                if (indexPath.row == 0) {
                    
                    // add a UISwitch control on the right
                    cell.textLabel.text = @"Use Current Location:";
                    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
                    [switchView setOn:NO animated:NO];
                    [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = switchView;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    [switchView release];
                }
                break;
            case 1:
                
                // Other locations
                locality = [self.delegate.modelArray objectAtIndex:indexPath.row];
                cell.textLabel.text = [locality description];
                break;
        }
    } else {
        if (indexPath.section == 1) {
            locality = [self.delegate.modelArray objectAtIndex:indexPath.row];
            cell.textLabel.text = [locality description];
        }
    }

    // allow reordering
    //cell.shouldIndentWhileEditing = NO;
    //cell.showsReorderControl = NO;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView
canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 1) ? YES : NO;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1 && editingStyle == UITableViewCellEditingStyleDelete)
    {
        // modify main model and view
        NSInteger row = indexPath.row;
        NSMutableArray* arr = self.delegate.modelArray;
        RSLocality* locality = [arr objectAtIndex:row];
        [modelDict removeObjectForKey:[locality apiId]];
        [arr removeObjectAtIndex:row];
        [self.delegate removePage:row];

        // remove the row
        [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 1) 
    ? UITableViewCellEditingStyleDelete 
    : UITableViewCellEditingStyleNone;
}

// Row reordering
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // whether a given row is eligible for reordering
    return (indexPath.section == 1) ? YES : NO;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
      toIndexPath:(NSIndexPath *)toIndexPath
{
    if (fromIndexPath.section == 1 && toIndexPath.section == 1) {
        
        // TODO: consider saving model to NSUserDefaults in the same block as updating
        // update model array
        NSMutableArray* arr = self.delegate.modelArray;
        NSString *item = [[arr objectAtIndex:fromIndexPath.row] retain];
        [arr removeObject:item];
        [arr insertObject:item atIndex:toIndexPath.row];
        [item release];
        
        // update controller view
        [self.delegate insertViewFromIndex:fromIndexPath.row toIndex:toIndexPath.row];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    // Limit record reordering to the source section. Also snap the record to
    // the first or last row of the section, depending on where the drag went.
    if (sourceIndexPath.section != proposedDestinationIndexPath.section) {
        NSInteger row = 0;
        if (sourceIndexPath.section < proposedDestinationIndexPath.section) {
            row = [tableView numberOfRowsInSection:sourceIndexPath.section] - 1;
        }
        return [NSIndexPath indexPathForRow:row inSection:sourceIndexPath.section];
    }
    return proposedDestinationIndexPath;
}

#pragma mark - NSURLConnection delegate methods

- (NSURLRequest *)connection:(NSURLConnection *)connection
			 willSendRequest:(NSURLRequest *)request
			redirectResponse:(NSURLResponse *)redirectResponse
{
	[theURL autorelease];
	theURL = [[request URL] retain];
	return request;
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
	[responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)data
{
	[responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // Deal with result returned by autocomplete API
    JSONDecoder* parser = [JSONDecoder decoder]; // autoreleased
    NSDictionary *data = [parser objectWithData:responseData];
    if (!data) {
        return;
    }
    NSString *status = [data objectForKey:@"status"];
    if (!status || ![status isEqualToString:@"OK"]) {
        return;
    }
    NSDictionary *result = [data objectForKey:@"result"];
    if (!result) {
        return;
    }
    
    // update locality object in modelDict
    RSLocality *locality = [modelDict objectForKey:_currentLocalityId];
    locality.formatted_address = [result objectForKey:@"formatted_address"];
    locality.name = [result objectForKey:@"name"];
    locality.vicinity = [result objectForKey:@"vicinity"];
    locality.url = [result objectForKey:@"url"];
    NSDictionary *location = [[result objectForKey:@"geometry"] objectForKey:@"location"];
    CLLocationCoordinate2D coord2d;
    coord2d.latitude = [[location objectForKey:@"lat"] doubleValue];
    coord2d.longitude = [[location objectForKey:@"lng"] doubleValue];
    locality.coord = coord2d;
    
    // save model array
    [self.delegate saveSettings];
    
    //cleanup
    [responseData release];
    responseData = nil;
}

#pragma mark - Screen orientation
-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // lock to portrait
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

@end
