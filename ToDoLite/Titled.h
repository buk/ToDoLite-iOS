//
//  Titled.h
//  ToDoLite
//
//  Created by Jens Alfke on 8/26/13.
//
//

#import <CouchbaseLite/CouchbaseLite.h>

/** Abstract superclass of List and Task. A generic model object with a title and creation date. */
@interface Titled : CBLModel

/** The "type" property value for documents that belong to this class. Abstract. */
+ (NSString*) docType;

/** Designated initializer. The "type" parameter sets the document type, which is used by
    views and the CBLModelFactory. */
- (instancetype) initInDatabase: (CBLDatabase*)database withTitle: (NSString*)title;

/** The object's user-visible title. */
@property (copy) NSString* title;

/** When the object was created. */
@property (readonly) NSDate* created_at;

@end
