#import "AFObjectProvider.h"
#import "AFRelationship.h"


#pragma mark Class Definition

@implementation AFObjectProvider


#pragma mark - Public Methods

- (void)_hydrateMockObject: (id)mockObject
	objectModel: (AFObjectModel *)objectModel
{
	// Get the mapped values.
	NSDictionary *relationshipsByPropertyKeyPath = objectModel.relationships;
	
	// Apply the mapped values, if present.
	if (relationshipsByPropertyKeyPath != nil)
	{
		for (NSString *propertyKeyPath in [relationshipsByPropertyKeyPath allKeys])
		{
			// If a mapping exists and is valid, set the value.
			id relationship = relationshipsByPropertyKeyPath[propertyKeyPath];
			
			if (AFIsNull(relationship) == NO
				&& [relationship isKindOfClass: AFRelationship.class])
			{
				// Don't crash on failing a parse/set.
				@try
				{
					// Use the relationship to get and set the value.
					[relationship update: mockResult
						values: values
						propertyName: propertyKeyPath
						provider: self];
				}
				@catch (NSException *exception)
				{
#if defined(DEBUG_OBJECT_PROVIDER)
					AFLog(AFLogLevelDebug, @"Failed to parse value for property: %@. Error: %@", propertyKeyPath, exception);
#endif
				}
			}
		}
	}
}


// Fabricate one of each model, returned under their root keys.
- (NSDictionary *)fabricate
{
	NSMutableDictionary *results = [NSMutableDictionary dictionary];

	NSDictionary *objectModelsByClassName = [AFObjectModel objectModels];
	
	NSMutableDictionary *mockResultByClassName = [NSMutableDictionary dictionary];
	
	// To establish links between objects, establish one of each object model, giving each a unique ID.
	for (NSString *modelClassName in [objectModelsByClassName allKeys])
	{
		Class modelClass = NSClassFromString(modelClassName);
		
		// Use the format "modelName=-id" to represent a model's ID.
		mockResultByClassName[modelClassName] = [self fetchOrCreate: modelClass
			idValue: [NSString stringWithFormat: @"%@-id", modelClassName]];
	}
	
	// For each object model, populate its properties (potentially linking to other models).
	for (NSString *modelClassName in [objectModelsByClassName allKeys])
	{
		AFObjectModel *objectModel = objectModelsByClassName[modelClassName];
	
		// Get the mock result.
		id mockResult = mockResultByClassName[modelClassName];
	
		// Hydrate the mock result.
		
		
		
		// Set the mock result under its root keys.
		for (NSString *rootKey in objectModel.rootKeys)
		{
			results[rootKey] = mockResult;
		}
		
		// Set the mock result under its collection keys.
		for (NSString *collectionKey in objectModel.collectionKeys)
		{
			results[collectionKey] = @[ mockResult ];
		}
	}
	
	return results;
}

// Parse all root and collection keys in the provided values.
- (NSDictionary *)parse: (NSDictionary *)values
{
	NSDictionary *objectModelsByClassName = [AFObjectModel objectModels];
	
	NSMutableDictionary *results = [NSMutableDictionary dictionary];

	// For each object model, check for its sideloading key - if it exists, parse it.
	for (NSString *modelClassName in [objectModelsByClassName allKeys])
	{
		AFObjectModel *objectModel = objectModelsByClassName[modelClassName];
	
		// Load models by collection keys.
		for (NSString *collectionKey in objectModel.collectionKeys)
		{
			if (AFIsNull([values objectForKey: collectionKey]) == NO)
			{
				NSArray *modelsJSON = values[collectionKey];
				
				NSMutableArray *modelResults = [NSMutableArray array];
				
				for (NSDictionary *modelJSON in modelsJSON)
				{
					Class modelClass = NSClassFromString(modelClassName);
					
					// Sideload the model.
					id model = [self updateOrCreate: modelClass
						values: modelJSON];
						
					// Add the model to the results.
					if (AFIsNull(model) == NO)
					{
						[modelResults addObject: model];
					}
				}
				
				// Set the results.
				results[collectionKey] = modelResults;
			}
		}
		
		// Load models by root key.
		for (NSString *rootKey in objectModel.rootKeys)
		{
			if (AFIsNull([values objectForKey: rootKey]) == NO)
			{
				Class modelClass = NSClassFromString(modelClassName);
		
				// Sideload the model.
				id model = [self updateOrCreate: modelClass
					values: values[rootKey]];
					
				if (AFIsNull(model) == NO)
				{
					results[rootKey] = model;
				}
			}
		}
	}
	
	return results;
}

- (id)create: (Class)myClass
{
	// By default, just allocate and init the class.
	id instance = [[myClass alloc]
		init];
	
	return instance;
}

- (id)create: (Class)myClass
	values: (NSDictionary *)values
{
	// Create an instance.
	id instance = [self create: myClass];
	
	// Update the instance, if created.
	if (AFIsNull(instance) == NO)
	{
		[self update: myClass
			instance: instance
			values: values];
	}
	
	return instance;
}

- (id)fetch: (Class)myClass
	values: (NSDictionary *)values
{
	// By default, this provider does no identity mapping. Return nil.
	return nil;
}

- (id)fetchOrCreate: (Class)myClass
	idValue: (NSString *)idValue
{
	id instance = nil;

	AFObjectModel *objectModel = [AFObjectModel objectModelForClass: myClass];
	
	// Empty and null are not valid ID values.
	if (AFIsEmpty(idValue) == NO)
	{
		// Get the key for the ID key.
		NSString *idKeyPath = objectModel.idKeyPath;
		AFRelationship *idRelationship = objectModel.relationships[idKeyPath];
		
		// Get the key value of the ID relationship.
		if (AFIsNull(idRelationship) == NO)
		{
			NSString *idKey = idRelationship.keys[0];
		
			// Form a fetch request with the object's key value.
			NSDictionary *values =
			@{
				idKey : idValue
			};
			
			// Fetch the instance.
			instance = [self fetch: myClass
				values: values];
		
			// Create the instance, if it didn't exist.
			if (AFIsNull(instance) == YES)
			{
				instance = [self create: myClass
					values: values];
			}
		}
	}
	else
	{
		// TODO: How should this be handled generally?
		// No ID was available, create an anonymous item.
		instance = [self create: myClass];
	}
	
	return instance;
}

- (id)updateOrCreate: (Class)myClass
	values: (NSDictionary *)values
{
	// Try to fetch an existing instance.
	id instance = [self fetch: myClass
		values: values];
	
	// Create the instance, if it wasn't found.
	if (AFIsNull(instance) == YES)
	{
		instance = [self create: myClass];
	}
	
	// Update the instance, if it exists.
	if (AFIsNull(instance) == NO)
	{
		[self update: myClass
			instance: instance
			values: values];
	}
	
	return instance;
}

- (void)update: (Class)myClass
	instance: (id)instance
	values: (NSDictionary *)values
{
	id myClassObject = (id)myClass;
	
	// Object models are cached by the AFObjectModel class.
	AFObjectModel *objectModel = [AFObjectModel objectModelForClass: myClass];
	
	if (objectModel != nil)
	{
		// Get the mapped values.
		NSDictionary *relationshipsByPropertyKeyPath = objectModel.relationships;
		
		// Apply the mapped values, if present.
		if (relationshipsByPropertyKeyPath != nil)
		{
			for (NSString *propertyKeyPath in [relationshipsByPropertyKeyPath allKeys])
			{
				// If a mapping exists and is valid, set the value.
				id relationship = relationshipsByPropertyKeyPath[propertyKeyPath];
				
				if (AFIsNull(relationship) == NO
					&& [relationship isKindOfClass: AFRelationship.class])
				{
					// Don't crash on failing a parse/set.
					@try
					{
						// Use the relationship to get and set the value.
						[relationship update: instance
							values: values
							propertyName: propertyKeyPath
							provider: self];
					}
					@catch (NSException *exception)
					{
#if defined(DEBUG_OBJECT_PROVIDER)
						AFLog(AFLogLevelDebug, @"Failed to parse value for property: %@. Error: %@", propertyKeyPath, exception);
#endif
					}
				}
			}
		}
	}
	
	// Call the update method, if implemented.
	if ([myClassObject respondsToSelector: @selector(update:values:provider:)] == YES)
	{
		[myClassObject update: instance
			values: values
			provider: self];
	}
}


@end
