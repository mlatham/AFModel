#import "AFObjectProvider.h"


#pragma mark Enumerations

typedef enum
{
	AFRelationshipTypeHasOne,
	AFRelationshipTypeHasMany,

} AFRelationshipType;


#pragma mark Class Interface

@interface AFRelationship : NSObject


#pragma mark - Properties

@property (nonatomic, assign, readonly) AFRelationshipType type;
@property (nonatomic, strong, readonly) NSArray * _Nullable keys;


#pragma mark - Constructors

- (id _Nonnull)initWithKeys: (NSArray * _Nonnull)keys;

- (id _Nonnull)initWithHasMany: (Class _Nonnull)hasManyClass
	keys: (NSArray * _Nonnull)keys;


#pragma mark - Static Methods

// Returns a relationship that resolves a single object or value and sets its value.
+ (instancetype _Nonnull)key: (NSString * _Nonnull)key;
+ (instancetype _Nonnull)keys: (NSArray * _Nonnull)keys;

// Returns a relationship that resolves one or many object instances and assigns them to a collection.
+ (instancetype _Nonnull)hasMany: (Class _Nonnull)hasManyClass
	keys: (NSArray * _Nonnull)keys;
+ (instancetype _Nonnull)hasMany: (Class _Nonnull)hasManyClass
	key: (NSString * _Nonnull)key;


#pragma mark - Instance Methods

// Update the target object with a set of values.
- (void)update: (id _Nullable)object
	values: (NSDictionary * _Nullable)values
	propertyName: (NSString * _Nullable)propertyName
	provider: (AFObjectProvider * _Nullable)provider;

// Transform a value.
- (id _Nullable)transformValue: (id _Nullable)value
	toClass: (Class _Nullable)toClass
	provider: (AFObjectProvider * _Nullable)provider;

- (AFPropertyInfo * _Nullable)propertyInfoForTarget: (id _Nullable)target
	propertyName: (NSString * _Nullable)propertyName;


@end
