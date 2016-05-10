#import "AFPropertyInfo.h"


#pragma mark Class Interface

@interface AFPropertyHelper : NSObject


#pragma mark - Static Methods

// Gets the property info for a class.

+ (AFPropertyInfo *)propertyInfoForPropertyName: (NSString *)propertyName
	class: (Class)class;

+ (AFPropertyInfo *)propertyInfoForPropertyName: (NSString *)propertyName
	className: (NSString *)className;


@end