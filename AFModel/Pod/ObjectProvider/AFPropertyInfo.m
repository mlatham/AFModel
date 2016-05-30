#import "AFPropertyInfo.h"


#pragma mark Class Variables

static NSRegularExpression *_regularExpression;


#pragma mark - Class Definition

@implementation AFPropertyInfo
{
	@private __strong Class _propertyClass;
	@private __strong NSString *_propertyClassName;
}


#pragma mark - Properties

- (void)setPropertyType: (NSString *)propertyType
{
	static dispatch_once_t once;
	dispatch_once(&once, ^
	{
		_regularExpression = [NSRegularExpression regularExpressionWithPattern: @"^RLMArray(<[a-z0-9]*>)$"
			options: NSRegularExpressionCaseInsensitive
			error: nil];
	});

	_propertyType = propertyType;
	
	// If this property is a pointer type, set the property class and class name (if available).
	if ([_propertyType characterAtIndex: 0] == '@')
	{
		// Resolve the type name from the property type string.
		NSString *typeName = [_propertyType substringFromIndex: 1];
		
		// Clear any quotes out of the class name.
		typeName = [typeName stringByReplacingOccurrencesOfString: @"\""
			withString: @""];
		
		NSTextCheckingResult *match = [_regularExpression firstMatchInString: typeName
			options: 0
			range: NSMakeRange(0, [typeName length])];
		
		if (match)
		{
			// Use a RLMArray directly.
			typeName = @"RLMArray";
		 }
	
		// Resolve and set the property class. NSClassFromString returns nil if typeName is not a class name.
		_propertyClass = NSClassFromString(typeName);
	
		// Only set the property class name if the class existed.
		if (AFIsNull(_propertyClass) == NO)
		{
			_propertyClassName = typeName;
		}
		else
		{
			_propertyClass = nil;
		}
	}
}


@end // @implementation AFPropertyInfo