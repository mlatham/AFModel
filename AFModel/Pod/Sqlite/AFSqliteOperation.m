#import "AFSqliteOperation.h"


#pragma mark Constants

static NSString * const FinishedKeyPath = @"isFinished";
static NSString * const ExecutingKeyPath = @"isExecuting";

#define RESULT_KEY @"result"
#define ERROR_KEY @"error"


#pragma mark - Class Definition

@implementation AFSqliteOperation
{
    @private SQLStatementBlock _statementBlock;
    @private SQLStatementCompletion _statementCompletion;
	
	@private SQLQueryBlock _queryBlock;
	@private SQLQueryCompletion _queryCompletion;
	
	@private UIBackgroundTaskIdentifier _exitBackgroundTask;
    @private NSRecursiveLock *_databaseLock;
    @private sqlite3 *_database;
	@private BOOL _executing;
	@private BOOL _finished;
	@private BOOL _completed;
}


#pragma mark - Constructors

- (id)initWithDatabase: (sqlite3 *)database
    lock: (NSRecursiveLock *)databaseLock
    statementBlock: (SQLStatementBlock)statementBlock
    statementCompletion: (SQLStatementCompletion)statementCompletion
{
	if ((self = [super init]) == NO)
	{
		return nil;
	}
    
	// Initialize instance variables.
	_database = database;
	_databaseLock = databaseLock;
	_statementBlock = AFIsNull(statementBlock) == NO
		? [statementBlock copy]
		: nil;
	_statementCompletion = AFIsNull(statementCompletion) == NO
		? [statementCompletion copy]
		: nil;
	
	// Immediately begin a background task.
	[self AF_beginExitBackgroundTask];
	
	return self;
}

- (id)initWithDatabase: (sqlite3 *)database
    lock: (NSRecursiveLock *)databaseLock
    queryBlock: (SQLQueryBlock)queryBlock
    queryCompletion: (SQLQueryCompletion)queryCompletion
{
	if ((self = [super init]) == NO)
	{
		return nil;
	}
	
	// Initialize instance variables.
	_database = database;
	_databaseLock = databaseLock;
	_queryBlock = AFIsNull(queryBlock) == NO
		? [queryBlock copy]
		: nil;
	_queryCompletion = AFIsNull(queryCompletion) == NO
		? [queryCompletion copy]
		: nil;
	
	// Immediately begin a background task.
	[self AF_beginExitBackgroundTask];
	
	return self;
}


#pragma mark - Public Methods

- (BOOL)isCompleted
{
	@synchronized(self)
	{
		return _completed;
	}
}


#pragma mark - Overridden Methods

- (void)start
{
	// abort if cancelled
	if ([self isCancelled] == YES)
	{
		// raise finished notification
		[self willChangeValueForKey: FinishedKeyPath];		
		@synchronized(self)
		{
			_finished = YES;
		}		
		[self didChangeValueForKey: FinishedKeyPath];
		
		// callback delegate, if required
		if (AFIsNull(_statementCompletion) == NO
			|| AFIsNull(_queryCompletion) == NO)
		{
			[self performSelectorOnMainThread: @selector(AF_raiseCancelled) 
				withObject: nil 
				waitUntilDone: YES];
		}
		
		// stop processing
		return;
	}

	// start main execution on new thread
	[self willChangeValueForKey: ExecutingKeyPath];
	[NSThread detachNewThreadSelector: @selector(main) 
		toTarget: self
		withObject: nil];
		
	// raise executing notifcation
	@synchronized(self)
	{
		_executing = YES;
	}
	[self didChangeValueForKey: ExecutingKeyPath];
}

- (void)main
{
	// start connection
	@autoreleasepool
	{
		BOOL databaseLockAquired = NO;
		BOOL databaseRollbackRequired = NO;
		NSError *error = nil;
		id result = nil;
		@try 
		{           
			// acquire database lock
			[_databaseLock lock];
			databaseLockAquired = YES;
			
			// abort if cancelled
			if ([self isCancelled] == YES)
			{
				return;
			}
		
			// begin transaction
			if (sqlite3_exec(_database, "BEGIN TRANSACTION", NULL, NULL, NULL) 
				== SQLITE_OK)
			{
				databaseRollbackRequired = YES;
			}
			
			// or throw
			else
			{
				[NSException raise: @"InvalidOperation" 
					format: @"Error beginning transaction: %s", 
					sqlite3_errmsg(_database)];
			}
			
			// abort if cancelled
			if ([self isCancelled] == YES)
			{
				return;
			}

			// Only one of these blocks should be set - a query or a statement.
			if (AFIsNull(_queryBlock) == NO)
			{
				result = _queryBlock(_database, &error);
			}
			else
			{
				_statementBlock(_database, &error);
			}
					
			// Abort if cancelled.
			if ([self isCancelled] == YES)
			{
				return;
			}

			// Commit transaction on success.
			if (error == nil)
			{
				// Mark rollback as not required.
				databaseRollbackRequired = NO;
				
				// Throw if commit fails.
				if (sqlite3_exec(_database, "COMMIT TRANSACTION", NULL, NULL, NULL) 
					!= SQLITE_OK)
				{
					[NSException raise: @"InvalidOperation" 
						format: @"Error committing transaction: %s", 
						sqlite3_errmsg(_database)];
				}
			}
			
			// Release database lock.
			[_databaseLock unlock];
			databaseLockAquired = NO;
		}
		
		// Handle any exceptions.
		@catch (NSException *e) 
		{
			// Simply log exceptions.
			AFLog(AFLogLevelError, @"async database execution exception: %@", [e reason]);
			
			// Convert the exception to an error.
			error = AFSqliteErrorFromException(e);
		}
		
		// Complete operation.
		@finally
		{
			// Rollback if required.
			if (databaseRollbackRequired == YES)
			{
				// Log error if rollback fails.
				if (sqlite3_exec(_database, "ROLLBACK TRANSACTION", NULL, NULL, 
					NULL) != SQLITE_OK)
				{
					AFLog(AFLogLevelError, @"Error rolling back transaction: %s", 
						sqlite3_errmsg(_database));
				}
			}
			
			if (databaseLockAquired == YES)
			{
				[_databaseLock unlock];
			}

			BOOL hasCallback = AFIsNull(_statementCompletion) == NO
				|| AFIsNull(_queryCompletion) == NO;

			// Raise completed (if required).
			if ([self isCancelled] == NO 
				&& hasCallback == YES)
			{
				NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
				
				if (result != nil)
				{
					dictionary[RESULT_KEY] = result;
				}
				
				if (error != nil)
				{
					dictionary[ERROR_KEY] = error;
				}
			
				[self performSelectorOnMainThread: @selector(AF_raiseCompleted:)
					withObject: dictionary
					waitUntilDone: YES];		
			}
		
			// raise executing/finished notifcations
			[self willChangeValueForKey: FinishedKeyPath];
			[self willChangeValueForKey: ExecutingKeyPath];
			@synchronized(self)
			{
				_executing = NO;
				_finished = YES;
			}
			[self didChangeValueForKey: ExecutingKeyPath];
			[self didChangeValueForKey: FinishedKeyPath];
		}
	} // @autoreleasepool
}

- (BOOL)isConcurrent
{
	return YES;
}

- (BOOL)isExecuting
{
	@synchronized(self)
	{
		return _executing;
	}
}

- (BOOL)isFinished
{
	@synchronized(self)
	{
		return _finished;
	}
}


#pragma mark - Private Methods

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

- (void)AF_raiseCompleted: (NSDictionary *)data
{
	// Immediately begin a background task.
	[self AF_endExitBackgroundTask];

	// Raise completion.
    NSError *error = [data objectForKey: ERROR_KEY];
	if (AFIsNull(_queryCompletion) == NO)
	{
		id result = [data objectForKey: RESULT_KEY];
		
		// Call completion.
		_queryCompletion(result, error);
	}
	else
	{
		// Call completion.
		_statementCompletion(error);
	}
}

- (void)AF_raiseCancelled
{
	// Immediately begin a background task.
	[self AF_endExitBackgroundTask];
	
	// Raise completion.
	if (AFIsNull(_queryCompletion) == NO)
	{
		// Call completion.
		_queryCompletion(nil, nil);
	}
	else
	{
		// Call completion.
		_statementCompletion(nil);
	}
}


@end