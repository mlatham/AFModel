#import "sqlite3.h"
#import "AFSqliteOperation.h"


#pragma mark Class Interface

@interface AFSqliteClient : NSObject


#pragma mark - Properties

@property (nonatomic, readonly) NSURL *databaseURL;


#pragma mark - Methods

- (id)initWithDatabaseNamed: (NSString *)databaseName;

- (void)execute: (SQLStatementBlock)statement
	error: (NSError **)error;

- (id)query: (SQLQueryBlock)query
	error: (NSError **)error;

- (AFSqliteOperation *)beginStatement: (SQLStatementBlock)statement
	completion: (SQLStatementCompletion)completion;

- (AFSqliteOperation *)beginQuery: (SQLQueryBlock)statement
	completion: (SQLQueryCompletion)completion;

- (BOOL)isExecutionCompleted: (AFSqliteOperation *)operation;
- (void)cancelExecution: (AFSqliteOperation *)operation;
- (void)endExecution: (AFSqliteOperation *)operation;

- (void)resetOperationQueue;
- (void)resetDatabase;


@end