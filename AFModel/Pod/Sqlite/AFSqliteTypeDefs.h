#ifndef AF_SQLITE_TYPEDEFS_H
#define AF_SQLITE_TYPEDEFS_H


#pragma mark - Helper Functions

static inline NSError *AFSqliteErrorFromException(NSException *exception)
{
	const int ERROR_CODE = 666;

	// Mark as failed.
	NSDictionary *userInfo = @{
		NSLocalizedDescriptionKey : [exception description]
	};
	
	// Create an error.
	return [NSError errorWithDomain: @"AFSqliteError"
		code: ERROR_CODE
		userInfo: userInfo];
}

static inline void AFBindColumnDoubleNumber(sqlite3_stmt *statement, int column, NSNumber *number)
{
	if (AFIsNull(number) == YES)
	{
		sqlite3_bind_null(statement, column);
	}
	else
	{
		sqlite3_bind_double(statement, column, [number doubleValue]);
	}
}


static inline void AFBindColumnIntNumber(sqlite3_stmt *statement, int column, NSNumber *number)
{
	if (AFIsNull(number) == YES)
	{
		sqlite3_bind_null(statement, column);
	}
	else
	{
		sqlite3_bind_int(statement, column, [number intValue]);
	}
}

static inline void AFBindColumnString(sqlite3_stmt *statement, int column, NSString *string)
{
	if (AFIsNull(string) == YES)
	{
		sqlite3_bind_null(statement, column);
	}
	else
	{
		sqlite3_bind_text(statement, column, [string UTF8String], -1, SQLITE_TRANSIENT);
	}
}

static inline void AFBindColumnUrl(sqlite3_stmt *statement, int column, NSURL *url)
{
	if (AFIsNull(url) == YES)
	{
		sqlite3_bind_null(statement, column);
	}
	else
	{
		sqlite3_bind_text(statement, column, [[url absoluteString] 
			UTF8String], -1, SQLITE_TRANSIENT);
	}
}

static inline void AFBindColumnDate(sqlite3_stmt *statement, int column, NSDate *date)
{
	if (AFIsNull(date) == YES)
	{
		sqlite3_bind_null(statement, column);
	}
	else
	{
		NSTimeInterval timestamp = [date timeIntervalSince1970];
		sqlite3_bind_double(statement, column, timestamp);
	}
}

static inline NSString *AFColumnText(sqlite3_stmt *statement, int column)
{
	char *text = (char *)sqlite3_column_text(statement, column);
	if (text == NULL)
	{
		return nil;
	}
	else
	{
		return [[NSString stringWithUTF8String: text] copy];
	}
}

static inline NSURL *AFColumnUrl(sqlite3_stmt *statement, int column)
{
	char *text = (char *)sqlite3_column_text(statement, column);
	if (text == NULL)
	{
		return nil;
	}
	else
	{
		return [NSURL URLWithString: [NSString stringWithUTF8String: text]];
	}
}

static inline NSDate *AFColumnDate(sqlite3_stmt *statement, int column)
{
	if (sqlite3_column_type(statement, column) == SQLITE_NULL)
	{
		return nil;
	}
	else
	{
		NSTimeInterval timestamp = sqlite3_column_double(statement, column);
		return [NSDate dateWithTimeIntervalSince1970: timestamp];
	}
}

static inline NSNumber *AFColumnIntNumber(sqlite3_stmt *statement, int column)
{
	if (sqlite3_column_type(statement, column) == SQLITE_NULL)
	{
		return nil;
	}
	else
	{
		int value = sqlite3_column_int(statement, column);
		return [NSNumber numberWithInt: value];
	}
}

static inline NSNumber *AFColumnDoubleNumber(sqlite3_stmt *statement, int column)
{
	if (sqlite3_column_type(statement, column) == SQLITE_NULL)
	{
		return nil;
	}
	else
	{
		double value = sqlite3_column_double(statement, column);
		return [NSNumber numberWithDouble: value];
	}
}

static inline BOOL AFColumnIsNullOrFalse(sqlite3_stmt *statement, int column)
{
	return sqlite3_column_type(statement, column) == SQLITE_NULL
		|| sqlite3_column_int(statement, column) == 0;
}

static inline void AFBeginTransaction(sqlite3 *database)
{
	// begin transaction
	if (sqlite3_exec(database, "BEGIN TRANSACTION", NULL, NULL, NULL) 
		!= SQLITE_OK)
	{
		[NSException raise: @"InvalidOperation" 
			format: @"Error beginning transaction: %s", 
			sqlite3_errmsg(database)];
	}
}

static inline void AFCommitTransaction(sqlite3 *database)
{
	// begin transaction
	if (sqlite3_exec(database, "COMMIT TRANSACTION", NULL, NULL, NULL) 
		!= SQLITE_OK)
	{
		[NSException raise: @"InvalidOperation" 
			format: @"Error committing transaction: %s", 
			sqlite3_errmsg(database)];
	}
}

static inline void AFRollbackTransaction(sqlite3 *database)
{
	// begin transaction
	if (sqlite3_exec(database, "ROLLBACK TRANSACTION", NULL, NULL, NULL) 
		!= SQLITE_OK)
	{
		[NSException raise: @"InvalidOperation" 
			format: @"Error rolling back transaction: %s", 
			sqlite3_errmsg(database)];
	}
}


#pragma mark - Type Definitions

typedef id		(^SQLQueryBlock)(sqlite3 *database, NSError **error);
typedef void	(^SQLQueryCompletion)(id result, NSError *error);

typedef void	(^SQLStatementBlock)(sqlite3 *database, NSError **error);
typedef void	(^SQLStatementCompletion)(NSError *error);


#endif /* AF_SQLITE_TYPEDEFS_H */
