#import "AFDBClient.h"
#import "AFDBOperation.h"


#pragma mark Constants

static NSString * const AFDBExtension = @"sqlite";


#pragma mark - Class Variables

static NSFileManager *_fileManager;
static NSBundle *_mainBundle;
static NSURL *_documentsURL;


#pragma mark - Class Definition

@implementation AFDBClient
{
	@private sqlite3 *_database;
	@private NSURL *_databaseURL;
	@private NSRecursiveLock *_databaseLock;
	@private NSOperationQueue *_asyncQueryQueue;
	@private UIBackgroundTaskIdentifier _exitBackgroundTask;
}


#pragma mark - Constructors

+ (void)initialize
{
	static BOOL classInitialized = NO;
	
	if (!classInitialized)
	{
		classInitialized = YES;
	
		// Set the file manager.
		_fileManager = [NSFileManager defaultManager];
		
		// Get the main bundle.
		_mainBundle = [NSBundle mainBundle];
		
		// Get documents folder root.
		_documentsURL = [[_fileManager
			URLsForDirectory: NSDocumentDirectory 
			inDomains: NSUserDomainMask] 
			objectAtIndex: 0];
	}
}

- (id)initWithDatabaseNamed: (NSString *)databaseName
{
    // Abort if base constructor fails.
	if ((self = [super init]) == nil)
	{
		return nil;
	}

	// Ensure database file is copied into documents folder.
	NSString *databaseFile = [NSString stringWithFormat: @"%@.%@", databaseName, AFDBExtension];
	_databaseURL = [_documentsURL URLByAppendingPathComponent: databaseFile];
	
	// Initialize the database, if it doesn't already exist.
	if ([AFDBClient AF_documentsFileExists: databaseFile] == NO)
	{
		BOOL initialized = [AFDBClient initializeDatabaseNamed: databaseName 
			overwrite: NO];
		if (initialized == NO)
		{
			return nil;
		}
	}
	
	// Initialize instance variables.
    _databaseLock = [[NSRecursiveLock alloc]
        init];
    _asyncQueryQueue = [[NSOperationQueue alloc]
        init];
    [_asyncQueryQueue setMaxConcurrentOperationCount: 1];
    
    // Create database connection.
	if (sqlite3_open([[_databaseURL path] UTF8String], &_database) != SQLITE_OK)
	{
        AFLog(AFLogLevelError, @"Unable to connect to database '%@': %s", databaseName,
            sqlite3_errmsg(_database));
	}

    // Enable foreign key support.
    else if (sqlite3_exec(_database, "PRAGMA foreign_keys = ON", NULL, NULL, NULL) != SQLITE_OK)
    {
        AFLog(AFLogLevelError, @"Unable to activate database foreign key support: %s", 
            sqlite3_errmsg(_database));
    }
	
	// Register for notifications.
	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector(AF_applicationDidEnterBackground)
		name: UIApplicationDidEnterBackgroundNotification
		object: nil];

    // Return initialized instance.
	return self;
}


#pragma mark - Destructors

- (void)dealloc 
{
	// Unregister notifications.
	[[NSNotificationCenter defaultCenter]
		removeObserver: self 
		name: UIApplicationDidEnterBackgroundNotification 
		object: nil];

	// Reset (ensures any async operations are stopped).
	[self reset];
	
	// Close database connection.
	sqlite3_close(_database);
}


#pragma mark - Public Methods

+ (BOOL)initializeDatabaseNamed: (NSString *)databaseName
	overwrite: (BOOL) overwrite
{
	NSString *databaseFile = [NSString stringWithFormat: @"%@.%@", databaseName, AFDBExtension];

	// Determine database target URL.
	NSURL *databaseURL = [_documentsURL URLByAppendingPathComponent: databaseFile];

	// Determine database source URL.
    NSURL *databaseBundleURL = [self AF_mainBundleURLForFile: databaseFile];

	// Copy database from bundle, if not yet created.
	BOOL copied = [self AF_copyFileFrom: databaseBundleURL
		to: databaseURL
		overwrite: overwrite];
		
	// Log if copy failed.
    if (copied == NO)
    {
        AFLog(AFLogLevelError, @"Failed to copy database to documents directory");
	}
	
	return copied;
}

- (id)execute: (SQLTaskDelegate)task
	success: (BOOL *)success
{
    // Start assuming success.
    *success = YES;

    // Acquire re-entrant lock.
    [_databaseLock lock];
    
    // Execute query.
    @try 
    {
        // Send query to delegate query.
        id result = task(_database, success);
        
        // Return result.
        return result;
    } 
    
    @catch (NSException *e)
    {
        // Fail.
        *success = NO;

        // Rethrow.
        @throw e;
    }
    
    @finally 
    {
        // Release lock.
        [_databaseLock unlock];
	}
}

- (DBExecutionToken)beginExecution: (SQLTaskDelegate)task
	completion: (SQLCompletedDelegate)completion
{
    // Create db operation.
    AFDBOperation *operation = [[AFDBOperation alloc]
        initWithDatabase: _database 
        lock: _databaseLock
        task: task 
        completion: completion];
    [operation setThreadPriority: 0.3];
        
    // Queue operation.
    [_asyncQueryQueue addOperation: operation];
    
    // Return operation as token.
    return operation;
}

- (BOOL)isExecutionCompleted: (DBExecutionToken)token
{
    NSArray *operations = [_asyncQueryQueue operations];
    NSUInteger operationIndex = [operations indexOfObjectIdenticalTo: token];
    return operationIndex != NSNotFound;
}

- (void)endExecution: (DBExecutionToken)token
{
    if ([self isExecutionCompleted: token] == NO)
    {
        NSOperation *operation = token;
        [operation waitUntilFinished];
    }
}

- (void)cancelExecution: (DBExecutionToken)token
{
    if ([self isExecutionCompleted: token] == NO)
    {
        NSOperation *operation = token;
        [operation cancel];
    }
}

- (void)reset
{
    [_asyncQueryQueue cancelAllOperations];
}


#pragma mark - Private Methods

- (void)AF_applicationDidEnterBackground
{
	// Begin the exit background task.
	[self AF_beginExitBackgroundTask];
	
	// Wait for all database operations to finish.
	[_asyncQueryQueue waitUntilAllOperationsAreFinished];
	
	// End the exit background task.
	[self AF_endExitBackgroundTask];
}

- (void)AF_beginExitBackgroundTask
{
	UIApplication *application = [UIApplication sharedApplication];
	_exitBackgroundTask = [application beginBackgroundTaskWithExpirationHandler: ^
	{
		[self AF_endExitBackgroundTask];
	}];
}

- (void)AF_endExitBackgroundTask
{
	UIApplication *application = [UIApplication sharedApplication];
	[application endBackgroundTask: _exitBackgroundTask];
    _exitBackgroundTask = UIBackgroundTaskInvalid;
}

+ (BOOL)AF_documentsFileExists: (NSString *)file
{
	NSURL *url = [_documentsURL URLByAppendingPathComponent: file
		isDirectory: NO];
	BOOL isDirectory = NO;
	BOOL exists = [_fileManager fileExistsAtPath: [url path]
		isDirectory: &isDirectory];
	return exists && !isDirectory;
}

+ (NSURL *)AF_mainBundleURLForFile: (NSString *)file
{	
	NSString *fileName = [[file lastPathComponent] stringByDeletingPathExtension];
	NSString *extension = [file pathExtension];
	return [_mainBundle URLForResource: fileName 
		withExtension: extension];
}

+ (BOOL)AF_copyFileFrom: (NSURL *)sourceURL
	to: (NSURL *)targetURL
	overwrite: (BOOL)overwrite
{
	// handle file already existing
    if ([_fileManager fileExistsAtPath: [targetURL path]] == YES)
    {
        // skip if not overwriting
        if (overwrite == NO)
        {
            return YES;
        }
        
        // otherwise, delete file (or abort if delete fails
        NSError *error = nil;
        if ([_fileManager removeItemAtURL: targetURL 
            error: &error] == NO)
        {
            AFLog(AFLogLevelDebug, @"Failed to delete file at '%@' before overwriting: %@",
                [targetURL absoluteString], [error localizedDescription]);
            return NO;
        }
    }
    
    // copy file
    NSError *error = nil;
    [_fileManager copyItemAtURL: sourceURL 
        toURL: targetURL 
		error: &error];
        
    // handle error
    if (error != nil)
    {
        AFLog(AFLogLevelDebug, @"Failed to copy file from '%@' to '%@': %@", [sourceURL absoluteString],
            [targetURL absoluteString], [error localizedDescription]);
        return NO;
    }
    
	// return success
	return YES;
}


@end