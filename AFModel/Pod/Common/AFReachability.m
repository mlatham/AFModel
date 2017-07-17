@import CoreFoundation;

#import "AFReachability.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>


#pragma mark Constants

NSString * const AFReachability_StateKeyPath = @"state";


#pragma mark - Class Definition

@implementation AFReachability
{
	@private SCNetworkReachabilityRef _reachabilityRef;
}


#pragma mark - Class Methods

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	AFReachability *reachability = (__bridge AFReachability *)info;
	[reachability updateStateForFlags: flags];
}


#pragma mark - Properties

- (NSString *)stateString
{
	switch (_state)
	{
		case AFReachabilityStateOnline:
			return @"ONLINE";
			
		case AFReachabilityStateOffline:
			return @"OFFLINE";
			
		case AFReachabilityStateUnknown:
			return @"UNKNOWN";
	}
}

- (void)setState: (AFReachabilityState)state
{
	_state = state;
}

- (NSString *)networkTypeString
{
	if (self.networkType == AFNetworkTypeWWAN)
	{
		CTTelephonyNetworkInfo *telephonyInfo = [CTTelephonyNetworkInfo new];
		NSString *currentRadio = telephonyInfo.currentRadioAccessTechnology;
		
		if ([currentRadio isEqualToString: CTRadioAccessTechnologyGPRS])
		{
			return @"GPRS";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyEdge])
		{
			return @"EDGE";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyWCDMA])
		{
			return @"WCDMA";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyHSDPA])
		{
			return @"HSDPA";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyHSUPA])
		{
			return @"HSUPA";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyCDMA1x])
		{
			return @"CDMA1X";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyCDMAEVDORev0])
		{
			return @"CDMAEVDOREV0";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyCDMAEVDORevA])
		{
			return @"CDMAEVDOREVA";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyCDMAEVDORevB])
		{
			return @"CDMAEVDOREVB";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyeHRPD])
		{
			return @"EHRPD";
		}
		else if ([currentRadio isEqualToString: CTRadioAccessTechnologyLTE])
		{
			return @"LTE";
		}
		else
		{
			// Default.
			return @"WWAN";
		}
	}
	else if (_reachability.networkType == AFNetworkTypeWiFi)
	{
		return @"WiFi";
	}
	else if (_reachability.networkType == AFNetworkTypeOffline)
	{
		return @"OFFLINE";
	}

	return @"UNKNOWN";
}

- (void)setNetworkType: (AFNetworkType)networkType
{
	_networkType = networkType;
}


#pragma mark - Constructors

+ (AFReachability *)reachabilityWithHostName: (NSString *)hostName;
{
	const char *hostNameCString = [hostName cStringUsingEncoding: NSASCIIStringEncoding];

    AFReachability *result = NULL;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, hostNameCString);
    if(reachability != NULL)
    {
        result = [[self alloc]
			init];
        if(result != NULL)
        {
            result->_reachabilityRef = reachability;
        }
    }
	
    return result;
}
 
+ (AFReachability *)reachabilityWithAddress: (const struct sockaddr_in *)hostAddress;
{
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)hostAddress);
    AFReachability *result = NULL;
    if(reachability!= NULL)
    {
        result = [[self alloc]
			init];
        if(result != NULL)
        {
            result->_reachabilityRef = reachability;
        }
    }
	
    return result;
}
 
+ (AFReachability *)reachabilityForInternetConnection;
{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
	
    return [self reachabilityWithAddress: &zeroAddress];
}

- (id)init
{
	// Abort if base initializer fails.
	if ((self = [super init]) == nil)
	{
		return nil;
	}
	
	// Initialize instance variables.
	_state = AFReachabilityStateUnknown;
	_networkType = AFNetworkTypeUnknown;
	
	// Return initialized instance.
	return self;
}


#pragma mark - Destructors

- (void) dealloc
{
    [self stop];
    
	if(_reachabilityRef!= NULL)
    {
        CFRelease(_reachabilityRef);
    }
}


#pragma mark - Public Methods

- (BOOL)start
{
    BOOL result = NO;
	
    SCNetworkReachabilityContext context = { 0, (__bridge void *)self, NULL, NULL, NULL };
    if(SCNetworkReachabilitySetCallback(_reachabilityRef, ReachabilityCallback, &context))
    {
        if(SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
        {
            result = YES;
        }
    }
	
    return result;
}
 
- (void)stop
{
    if(_reachabilityRef != NULL)
    {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
}


#pragma mark - Private Methods

- (void)updateStateForFlags: (SCNetworkReachabilityFlags)flags
{
	AFReachabilityState state = AFReachabilityStateOffline;
	AFNetworkType networkType = AFNetworkTypeUnknown;
	
	SCNetworkReachabilityFlags updateFlags;
	BOOL success = SCNetworkReachabilityGetFlags(_reachabilityRef, &updateFlags);
	
	// Determine state.
    if (success == YES)
	{
		if ((updateFlags & kSCNetworkFlagsReachable)
			&& !(updateFlags & kSCNetworkFlagsConnectionRequired))
		{
			// Target host is reachable.
			state = AFReachabilityStateOnline;
		}
		else
		{
			// Target host is reachable.
			state = AFReachabilityStateOffline;
		}
		
		if ((updateFlags & kSCNetworkReachabilityFlagsReachable) == 0)
		{
			networkType = AFNetworkTypeOffline;
		}
		else if ((updateFlags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
		{
			networkType = AFNetworkTypeWWAN;
		}
		else
		{
			networkType = AFNetworkTypeWiFi;
		}
	}
	else
	{
		// Target host is reachable.
		state = AFReachabilityStateOffline;
		networkType = AFNetworkTypeOffline;
	}
	
	// Set state, if required.
	if (self.state != state)
	{
		self.state = state;
		AFLog(AFLogLevelDebug, @"Reachability: %@", self.stateString);
	}
	
	if (self.networkType != networkType)
	{
		self.networkType = networkType;
		AFLog(AFLogLevelDebug, @"Network type: %@", self.networkTypeString);
	}
}


@end
