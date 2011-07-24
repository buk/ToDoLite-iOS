//
//  RootViewController.m
//  Couchbase Mobile
//
//  Created by Jan Lehnardt on 27/11/2010.
//  Copyright 2011 Couchbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.
//

#import "RootViewController.h"
#import "NewItemViewController.h"
#import <CouchCocoa/CouchCocoa.h>

@implementation RootViewController
@synthesize items;
@synthesize activityButtonItem;
@synthesize activity;
@synthesize database;

#pragma mark -
#pragma mark View lifecycle

-(CouchDatabase *) getDatabase {
	return database;
}



-(void)couchbaseDidStart:(NSURL *)serverURL {
//    CouchServer *server = [[CouchServer alloc] initWithURL: serverURL];
    CouchServer *server = [[CouchServer alloc] init]; //local makes app testing easier
    self.database = [[server databaseNamed: @"grocery-sync"] retain];
    self.database.tracksChanges = YES;

    [server release];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(databaseChanged:)
                                                 name: kCouchDatabaseChangeNotification 
                                               object: database];
    
    [self loadItemsIntoView];
    [self setupSync];
    self.navigationItem.leftBarButtonItem.enabled = YES;
}

- (void) databaseChanged: (NSNotification*)n {
    // Wait to redraw the table, else there is a race condition where if the
    // DemoItem gets notified after I do, it won't have updated timeSinceExternallyChanged yet.
    [self performSelector: @selector(loadItemsDueToChanges) withObject: nil afterDelay:0.0];
}

- (void)viewDidLoad {
    [super viewDidLoad];
   
    UIBarButtonItem* addItem = [[UIBarButtonItem alloc]
                           initWithTitle:@"New Item" style:UIBarButtonItemStyleBordered target:self action:@selector(addItem)];
    self.navigationItem.leftBarButtonItem = addItem;
    [addItem release];

    
	self.activity = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
	self.activityButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:activity] autorelease];
	self.activityButtonItem.enabled = NO;
	self.navigationItem.rightBarButtonItem = activityButtonItem;
}

-(void)setupSync
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *servername = [defaults objectForKey:@"servername"];
    NSURL *remoteURL = [NSURL URLWithString:servername];
    RESTOperation *pull = [database pullFromDatabaseAtURL: remoteURL options: kCouchReplicationContinuous];
    [pull onCompletion:^() {
        NSLog(@"continous sync triggered from %@", servername);
	}];
    RESTOperation *push = [database pushToDatabaseAtURL: remoteURL options: kCouchReplicationContinuous];
    [push onCompletion:^() {
        NSLog(@"continous sync triggered to %@", servername);
	}];
}

-(void)loadItemsDueToChanges {
    NSLog(@"loadItemsDueToChanges");
    [self refreshItems];
    [self.tableView reloadData];
}

-(void)loadItemsIntoView {
    [self refreshItems];
    [self.tableView reloadData];
}

-(void) refreshItems {
    [self.activity startAnimating];
    CouchQuery *allDocs = [database getAllDocuments];
    allDocs.descending = YES;
    self.items = allDocs.rows;
    [self.activity stopAnimating];
}




-(void)newItemAdded {
	[self loadItemsIntoView];
	[self dismissModalViewControllerAnimated:YES];
}


-(void)addItem {
    NewItemViewController *newItemVC = [[NewItemViewController alloc] initWithNibName:@"NewItemViewController" bundle:nil];
    newItemVC.delegate = self;
    UINavigationController *newItemNC = [[UINavigationController alloc] initWithRootViewController:newItemVC];
    [self presentModalViewController:newItemNC animated:YES];
    [newItemVC release];
    [newItemNC release];
}


#pragma mark -
#pragma mark Table view data source

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.items count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
	// Configure the cell.
	CouchQueryRow *row = [self.items rowAtIndex:indexPath.row];
    if ([row.documentProperties valueForKey:@"check"] == [NSNumber numberWithInteger: 1]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    };
	cell.textLabel.text = [row.documentProperties valueForKey:@"text"];
    return cell;
}


// Override to support conditional editing of the table view.
//- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
//    // Return NO if you do not want the specified item to be editable.
//    return YES;
//}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source.
        RESTOperation* op = [[[items rowAtIndex:indexPath.row] document] DELETE];
        [op onCompletion: ^{
            [self refreshItems]; // BLOCKING
            // TODO return to the smooth style of deletion (eg animate the delete before the server responds...)
            //		[items removeRowAtIndex: position];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }];
        [op start];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }   
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CouchQueryRow *row = [self.items rowAtIndex:indexPath.row];
    CouchDocument *doc = [row document];
    NSMutableDictionary *docContent = [[NSMutableDictionary alloc] init];//[doc valueForKey:@"content"];
    [docContent addEntriesFromDictionary:row.documentProperties];
    id zero = [NSNumber numberWithInteger: 0];
    id one = [NSNumber numberWithInteger: 1];
    
    if ([docContent valueForKey:@"check"] == one) {
        [docContent setObject:zero forKey:@"check"];
    }
    else{
        [docContent setObject:one forKey:@"check"];
    
    }
    //create a document of the dictionary and replace the old document
    RESTOperation* op = [doc putProperties:docContent];
    [op onCompletion: ^{
        if (op.error) {
            NSLog(@"error updating doc %@", [op.error description]);
        }
        NSLog(@"updated doc! %@", [op description]);
        [self loadItemsIntoView];
    }];
    [op start];
    [docContent release];
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
    [items release];
    [database release];
    [super dealloc];
}


@end

