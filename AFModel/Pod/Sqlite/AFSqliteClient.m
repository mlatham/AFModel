#import "AFSqliteClient.h"


#pragma mark Constants

static NSString * const AFDBExtension = @"sqlite";


#pragma mark - Class Variables

static NSFileManager *_fileManager;
static NSBundle *_mainBundle;
static NSURL *_documentsURL;


#pragma mark - Class Definition

@implementation AFSqliteClient
{
	@private BOOL _connected;
	@private sqlite3 *_database;
	@private NSURL *_databaseURL;
	@private NSString *_databaseName;
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
	_databaseName = databaseName;
	
	// Initialize instance variables.
    _databaseLock = [[NSRecursiveLock alloc]
        init];
    _asyncQueryQueue = [[NSOperationQueue alloc]
        init];
    [_asyncQueryQueue setMaxConcurrentOperationCount: 1];
	
	// Open the database connection.
	[self openConnection];

    // Return initialized instance.
	return self;
}


#pragma mark - Destructors

- (void)dealloc 
{
	// Close the connection.
	[self closeConnection];
}


#pragma mark - Public Methods

- (void)execute: (SQLStatementBlock)statement
	error: (NSError **)error
{
    // Acquire re-entrant lock.
    [_databaseLock lock];
    
    // Execute query.
    @try 
    {
        // Execute statement.
        statement(_database, error);
    } 
    
    @catch (NSException *e)
    {
		// Convert the exception to an error.
		*error = AFSqliteErrorFromException(e);
	
		// Don't re-throw.
    }
    
    @finally 
    {
        // Release lock.
        [_databaseLock unlock];
	}
}

- (id)query: (SQLQueryBlock)query
	error: (NSError **)error
{
	// Acquire re-entrant lock.
    [_databaseLock lock];
	
	id result = nil;
	
    // Execute query.
    @try 
    {
        // Execute statement.
        result = query(_database, error);
    } 
    
    @catch (NSException *e)
    {
		// Convert the exception to an error.
		*error = AFSqliteErrorFromException(e);
	
		// Don't re-throw.
    }
    
    @finally 
    {
        // Release lock.
        [_databaseLock unlock];
	}
	
	return result;
}

- (AFSqliteOperation *)beginStatement: (SQLStatementBlock)statement
	completion: (SQLStatementCompletion)completion
{
	// Create db operation.
    AFSqliteOperation *operation = [[AFSqliteOperation alloc]
        initWithDatabase: _database
		lock: _databaseLock
		statementBlock: statement
		statementCompletion: completion];
    [operation setThreadPriority: 0.3];
        
    // Queue operation.
    [_asyncQueryQueue addOperation: operation];
    
    // Return operation as token.
    return operation;
}

- (AFSqliteOperation *)beginQuery: (SQLQueryBlock)statement
	completion: (SQLQueryCompletion)completion
{
	// Create db operation.
    AFSqliteOperation *operation = [[AFSqliteOperation alloc]
        initWithDatabase: _database
		lock: _databaseLock
		queryBlock: statement
		queryCompletion: completion];
    [operation setThreadPriority: 0.3];
        
    // Queue operation.
    [_asyncQueryQueue addOperation: operation];
    
    // Return operation as token.
    return operation;
}

- (BOOL)isExecutionCompleted: (AFSqliteOperation *)operation
{
    NSArray *operations = [_asyncQueryQueue operations];
    NSUInteger operationIndex = [operations indexOfObjectIdenticalTo: operation];
    return operationIndex != NSNotFound;
}

- (void)endExecution: (AFSqliteOperation *)operation
{
    if ([self isExecutionCompleted: operation] == NO)
    {
        [operation waitUntilFinished];
    }
}

- (void)cancelExecution: (AFSqliteOperation *)operation
{
    if ([self isExecutionCompleted: operation] == NO)
    {
        [operation cancel];
    }
}

- (void)resetOperationQueue
{
    [_asyncQueryQueue cancelAllOperations];
}

- (void)resetDatabase
{
	// Acquire re-entrant lock.
    [_databaseLock lock];

	@try
	{
		// Close the connection.
		[self closeConnection];
		
		// Delete the database file.
		NSError *error = nil;
		if ([_fileManager removeItemAtURL: _databaseURL
			error: &error] == NO)
		{
			AFLog(AFLogLevelError, @"Failed to delete file at '%@' before overwiting: %@",
				[_databaseURL absoluteString], [error localizedDescription]);
		}
		
		// Re-open the connection.
		[self openConnection];
	}
	
	@finally 
    {
        // Release lock.
        [_databaseLock unlock];
	}

}

- (void)closeConnection
{
	if (_connected == NO)
	{
		return;
	}

	// Unregister notifications.
	[[NSNotificationCenter defaultCenter]
		removeObserver: self 
		name: UIApplicationDidEnterBackgroundNotification 
		object: nil];

	// Reset (ensures any async operations are stopped).
	[self resetOperationQueue];
	
	// Close database connection.
	sqlite3_close(_database);
	
	// Track connection state.
	_connected = NO;
}

- (void)openConnection
{
	if (_connected == YES)
	{
		return;
	}

	// Create database connection.
	if (sqlite3_open([[_databaseURL path] UTF8String], &_database) != SQLITE_OK)
	{
        AFLog(AFLogLevelError, @"Unable to connect to database '%@': %s", _databaseName,
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
	
	// Track connection state.
	_connected = YES;
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
