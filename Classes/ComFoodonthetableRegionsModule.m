/**
 * Your Copyright Here
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */
#import "ComFoodonthetableRegionsModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"

@implementation ComFoodonthetableRegionsModule

@synthesize locationManager, lastEvent, options, checkLocal;


#pragma mark - Titanium Module

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"01778b3e-0a89-434b-8318-79d7ff74bc36";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"com.foodonthetable.regions";
}

#pragma mark Lifecycle

-(void)startup
{
	// this method is called when the module is first loaded
	// you *must* call the superclass
	[super startup];
	// NSLog(@"[INFO] [REGIONS] STARTUP FIRED");
}

-(void)shutdown:(id)sender
{
	// this method is called when the module is being unloaded
	// typically this is during shutdown. make sure you don't do too
	// much processing here or the app will be quit forceably
    [locationManager release];
    
    // NSLog(@"[INFO] [REGIONS] SHUTDOWN FIRED");
    
	// you *must* call the superclass
	[super shutdown:sender];
}

#pragma mark Cleanup

-(void)dealloc
{
    // NSLog(@"[INFO] [REGIONS] DEALLOC FIRED");
    
	// release any resources that have been retained by the module
	[super dealloc];
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
	// optionally release any resources that can be dynamically
	// reloaded once memory is available - such as caches
	[super didReceiveMemoryWarning:notification];
}

#pragma mark Listener Notifications

-(void)_listenerAdded:(NSString *)type count:(int)count
{
//	// NSLog(@"[INFO] listenerAdded %@", type);
	if (count == 1 && [type isEqualToString:@"my_event"])
	{
		// the first (of potentially many) listener is being added 
		// for event named 'my_event'
	}
}

-(void)_listenerRemoved:(NSString *)type count:(int)count
{
//	// NSLog(@"[INFO] listenerRemoved %@", type);
	if (count == 0 && [type isEqualToString:@"my_event"])
	{
		// the last listener called for event named 'my_event' has
		// been removed, we can optionally clean up any resources
		// since no body is listening at this point for that event
	}
}

#pragma mark - Regions Implementation


-(CLLocationManager*)getLocationManager
{
//    // NSLog(@"[INFO] [REGIONS] GET LOCATION MANAGER FIRED");
    
    if (NULL == locationManager) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // // NSLog(@"[INFO] [REGIONS] LOCATION MANAGER INITIALIZING");
            
            // Location Management stuff
            locationManager = [[CLLocationManager alloc] init];
            locationManager.delegate = self;
            locationManager.distanceFilter = kCLLocationAccuracyNearestTenMeters;
            locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            
            if(![self regionMonitoringEnabled]) {
                // NSLog(@"[INFO] %@",@"This app requires region monitoring features which are unavailable on this device.");
                return;
            }
            
            // Make sure we check the users current location
            checkLocal = TRUE;
            
            [locationManager startUpdatingLocation];
        
        });
        
        [self fireEvent:@"didInitialize"];
    }
    
    return locationManager;
}



- (CLRegion*)dictToRegion:(NSDictionary*)dictionary
{
    NSString *identifier = [dictionary valueForKey:@"id"];
    CLLocationDegrees latitude = [[dictionary valueForKey:@"lat"] doubleValue];
    CLLocationDegrees longitude =[[dictionary valueForKey:@"lng"] doubleValue];
    CLLocationCoordinate2D centerCoordinate = CLLocationCoordinate2DMake(latitude, longitude);
    CLLocationDistance regionRadius = [[dictionary valueForKey:@"radius"] doubleValue];
    
    if(regionRadius > locationManager.maximumRegionMonitoringDistance)
    {
        regionRadius = locationManager.maximumRegionMonitoringDistance;
    }
    
    NSString *version = [[UIDevice currentDevice] systemVersion];
    CLRegion * region =nil;
    
    if([version floatValue] >= 7.0f) //for iOS7
    {
        region =  [[CLCircularRegion alloc] initWithCenter:centerCoordinate
                                                    radius:regionRadius
                                                identifier:identifier];
    }
    else // iOS 7 below
    {
        region = [[CLRegion alloc] initCircularRegionWithCenter:centerCoordinate
                                                         radius:regionRadius
                                                     identifier:identifier];
    }
    return  region;
}

- (BOOL*)regionMonitoringEnabled
{
    
    BOOL *enabled = false;
    
    NSString *version = [[UIDevice currentDevice] systemVersion];
    
    if([version floatValue] >= 7.0f){
        // For iOS 7
        enabled = [CLLocationManager isMonitoringAvailableForClass:[CLRegion class]];
    } else {
        // For iOS 6
        enabled = [CLLocationManager regionMonitoringAvailable];
    };

    return enabled;
}

- (NSNumber*)calculateDistanceInMetersBetweenCoord:(CLLocationCoordinate2D)coord1 coord:(CLLocationCoordinate2D)coord2 {
    NSInteger nRadius = 6371; // Earth's radius in Kilometers
    double latDiff = (coord2.latitude - coord1.latitude) * (M_PI/180);
    double lonDiff = (coord2.longitude - coord1.longitude) * (M_PI/180);
    double lat1InRadians = coord1.latitude * (M_PI/180);
    double lat2InRadians = coord2.latitude * (M_PI/180);
    double nA = pow ( sin(latDiff/2), 2 ) + cos(lat1InRadians) * cos(lat2InRadians) * pow ( sin(lonDiff/2), 2 );
    double nC = 2 * atan2( sqrt(nA), sqrt( 1 - nA ));
    double nD = nRadius * nC;
    // convert to meters
    return @(nD*1000);
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    if(checkLocal)
    {
        // Make sure we check the users current location
        checkLocal = TRUE;
        NSSet * monitoredRegions = locationManager.monitoredRegions;
        CLLocation *newLocation = (CLLocation*)[locations lastObject];
        if(monitoredRegions)
        {
            [monitoredRegions enumerateObjectsUsingBlock:^(CLRegion *region,BOOL *stop)
             {
                 NSString *identifer = region.identifier;
                 CLLocationCoordinate2D centerCoords =[(CLCircularRegion *)region center];
                 CLLocationCoordinate2D currentCoords= CLLocationCoordinate2DMake(newLocation.coordinate.latitude,newLocation.coordinate.longitude);
                 CLLocationDistance radius = [(CLCircularRegion *)region radius];

                 NSNumber * currentLocationDistance =[self calculateDistanceInMetersBetweenCoord:currentCoords coord:centerCoords];
                 if([currentLocationDistance floatValue] < radius)
                 {
                    dispatch_async(dispatch_get_main_queue(), ^{

                      //stop Monitoring Region temporarily
                      [locationManager stopMonitoringForRegion:region];

                      [self locationManager:locationManager didEnterRegion:region];
                      //start Monitoing Region again.
                      [locationManager startMonitoringForRegion:region];
                    });
                 }
             }];
        }
        
        [locationManager stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	NSString *formattedError = [NSString stringWithFormat:@"%@", error];
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                           formattedError,@"error",
                           nil];

    [self fireEvent:@"didFailWithError" withObject:event];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region  {
    
    NSString *msg = [NSString stringWithFormat:@"Enter %@ at %@", region.identifier, [NSDate date]];
    if (![msg isEqualToString:self.lastEvent])
    {
        [self setLastEvent:[NSString stringWithString:msg]];
        NSDictionary *region_info = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithDouble:[(CLCircularRegion *)region center].latitude],@"lat",
                                     [NSNumber numberWithDouble:[(CLCircularRegion *)region center].longitude],@"lng",
                                     [NSNumber numberWithDouble:[(CLCircularRegion *)region radius]],@"radius",
                                     region.identifier,@"id",
                                     nil];
    
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               region_info,@"region",
                               msg, @"message",
                               nil];

        [self fireEvent:@"didEnterRegion" withObject:event];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    
    NSString *msg = [NSString stringWithFormat:@"Exit %@ at %@", region.identifier, [NSDate date]];
    if (![msg isEqualToString:self.lastEvent])
    {
        [self setLastEvent:[NSString stringWithString:msg]];
        NSDictionary *region_info = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithDouble:[(CLCircularRegion *)region center].latitude],@"lat",
                                    [NSNumber numberWithDouble:[(CLCircularRegion *)region center].longitude],@"lng",
                                    [NSNumber numberWithDouble:[(CLCircularRegion *)region radius]],@"radius",
                                 region.identifier,@"id",
                                 nil];
    
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               region_info,@"region",
                               msg, @"message",
                               nil];

        [self fireEvent:@"didExitRegion" withObject:event];
    }
}


- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    
	NSString *formattedError = [NSString stringWithFormat:@"%@", error];

    [self setLastEvent:@""];
    NSDictionary *region_info = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithDouble:[(CLCircularRegion *)region center].latitude],@"lat",
                                 [NSNumber numberWithDouble:[(CLCircularRegion *)region center].longitude],@"lng",
                                 [NSNumber numberWithDouble:[(CLCircularRegion *)region radius]],@"radius",
                                 region.identifier,@"id",
                                 nil];
    
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                           formattedError,@"error",
                           region_info,@"region",
                           nil];
    [self fireEvent:@"monitoringDidFailForRegion" withObject:event];
}

#pragma Public APIs

-(void)initialize:(id)newOptions
{
    ENSURE_SINGLE_ARG(newOptions, NSDictionary);
    [self setOptions:newOptions];
    
    [self getLocationManager];
}

// Force to check the local location
// to see if you're in a region
-(void)checkLocation:(id)args
{
    [self setCheckLocal:TRUE];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Start monitoring for that first check
        [locationManager startUpdatingLocation];
    });
}

-(void)startMonitoring:(id)region
{
    
    ENSURE_UI_THREAD(startMonitoring,region);
    ENSURE_SINGLE_ARG(region,NSDictionary);
    
    if ([self regionMonitoringEnabled]) {
        
        CLRegion *newRegion = [self dictToRegion:region];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self getLocationManager] startMonitoringForRegion:newRegion];
        });
        
        [newRegion release];
        
        [self fireEvent:@"startedMonitoringRegion" withObject:region];
    } else {
        NSLog(@"[DEBUG] [REGIONS] regionMonitoring not available");
    }
}

-(void)startMonitoringRegions:(id)args
{
    
    // NSLog(@"[INFO] [REGIONS] [GEOFENCE] START MONITORING MULTIPLE REGIONS");
    
    ENSURE_UI_THREAD(startMonitoringRegions, args);
    
    // Can we do this
    if ([self regionMonitoringEnabled]) {
        
        NSArray * regions = [[args objectAtIndex:0]retain];
        
        // Iterate through the regions and stop them all
        for (int i = 0; i < [regions count]; i++) {
            CLRegion *newRegion = [self dictToRegion:[regions objectAtIndex:i]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self getLocationManager] startMonitoringForRegion:newRegion];
            });
            
            [newRegion release];
        }
        
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               regions,@"regions",
                               nil];
        
        [self fireEvent:@"startedMonitoringRegions" withObject:event];

    } else {
        NSLog(@"[DEBUG] [REGIONS] regionMonitoring not available");
    }
}


-(void)stopMonitoringAllRegions:(id)args
{
    ENSURE_UI_THREAD(stopMonitoringAllRegions, args);
    
    if ([self regionMonitoringEnabled]) {
        @try {
            NSArray *regions = [[[self getLocationManager] monitoredRegions] allObjects];
            
            int size = [regions count];
            
            // Iterate through the regions and add annotations to the map for each of them.
            for (int i = 0; i < [regions count]; i++) {
                CLRegion *region = [regions objectAtIndex:i];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[self getLocationManager] stopMonitoringForRegion:region];
                });
            }
        } @catch (NSException *exception) {
            // Well... that didn't work...
        }
    } else {
        //  NSLog(@"[DEBUG] [REGIONS] regionMonitoring not available");
    };
}

// NOTE: not on the UI thread since it returns something... hmmmm...
// If this is called too fast, it could cause problems
-(id)monitoredRegions:(id)args
{
    if ([self regionMonitoringEnabled]) {
        
        if (locationManager){
            // Get all regions being monitored for this application.
            NSArray *regions = [[[self getLocationManager] monitoredRegions] allObjects];
            NSMutableArray* jsRegions = [NSMutableArray arrayWithCapacity:[regions count]];
            
            // Iterate through the regions and add annotations to the map for each of them.
            for (int i = 0; i < [regions count]; i++) {
                CLRegion *region = [regions objectAtIndex:i];
                NSDictionary *jsRegion = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithDouble:[(CLCircularRegion *)region center].latitude],@"lat",
                                          [NSNumber numberWithDouble:[(CLCircularRegion *)region center].longitude],@"lng",
                                          [NSNumber numberWithDouble:[(CLCircularRegion *)region radius]],@"radius",
                                          region.identifier,@"id",
                                          nil];
                [jsRegions addObject:jsRegion];
            }
            return jsRegions;
        } else {
            return [NSMutableArray arrayWithCapacity:0];
        }
    } else {
        NSLog(@"[DEBUG] [REGIONS] regionMonitoring not available");

        return [NSMutableArray arrayWithCapacity:0];
    };
}

@end
