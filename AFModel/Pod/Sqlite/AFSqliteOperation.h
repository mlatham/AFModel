#import "sqlite3.h"
#import "AFSqliteTypeDefs.h"


#pragma mark Class Interface

@interface AFSqliteOperation : NSOperation


#pragma mark - Methods

- (id)initWithDatabase: (sqlite3 *)database
    lock: (NSRecursiveLock *)databaseLock
    statementBlock: (SQLStatementBlock)statementBlock
    statementCompletion: (SQLStatementCompletion)statementCompletion;

- (id)initWithDatabase: (sqlite3 *)database
    lock: (NSRecursiveLock *)databaseLock
    queryBlock: (SQLQueryBlock)queryBlock
    queryCompletion: (SQLQueryCompletion)queryCompletion;
    
- (BOOL)isCompleted;


@end