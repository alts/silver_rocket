//
//	PlaylistController.m
//	Cog
//
//	Created by Vincent Spader on 3/18/05.
//	Copyright 2005 Vincent Spader All rights reserved.
//

#import "PlaylistEntry.h"
#import "PlaylistLoader.h"
#import "PlaybackController.h"
#import "Shuffle.h"
#import "SpotlightWindowController.h"
#import "RepeatTransformers.h"
#import "ShuffleTransformers.h"
#import "StatusImageTransformer.h"
#import "ToggleQueueTitleTransformer.h"

#import "Logging.h"


#define UNDO_STACK_LIMIT 0

@implementation PlaylistController

@synthesize currentEntry;

+ (void)initialize {
	NSValueTransformer *repeatNoneTransformer = [[[RepeatModeTransformer alloc] initWithMode:RepeatNone] autorelease];
    [NSValueTransformer setValueTransformer:repeatNoneTransformer
                                    forName:@"RepeatNoneTransformer"];

	NSValueTransformer *repeatAllTransformer = [[[RepeatModeTransformer alloc] initWithMode:RepeatAll] autorelease];
    [NSValueTransformer setValueTransformer:repeatAllTransformer
                                    forName:@"RepeatAllTransformer"];

	NSValueTransformer *repeatModeImageTransformer = [[[RepeatModeImageTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:repeatModeImageTransformer
                                    forName:@"RepeatModeImageTransformer"];


	NSValueTransformer *shuffleOffTransformer = [[[ShuffleModeTransformer alloc] initWithMode:ShuffleOff] autorelease];
    [NSValueTransformer setValueTransformer:shuffleOffTransformer
                                    forName:@"ShuffleOffTransformer"];

	NSValueTransformer *shuffleAlbumsTransformer = [[[ShuffleModeTransformer alloc] initWithMode:ShuffleAlbums] autorelease];
    [NSValueTransformer setValueTransformer:shuffleAlbumsTransformer
                                    forName:@"ShuffleAlbumsTransformer"];

	NSValueTransformer *shuffleAllTransformer = [[[ShuffleModeTransformer alloc] initWithMode:ShuffleAll] autorelease];
    [NSValueTransformer setValueTransformer:shuffleAllTransformer
                                    forName:@"ShuffleAllTransformer"];

	NSValueTransformer *shuffleImageTransformer = [[[ShuffleImageTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:shuffleImageTransformer
                                    forName:@"ShuffleImageTransformer"];



	NSValueTransformer *statusImageTransformer = [[[StatusImageTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:statusImageTransformer
                                    forName:@"StatusImageTransformer"];

	NSValueTransformer *toggleQueueTitleTransformer = [[[ToggleQueueTitleTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:toggleQueueTitleTransformer
                                    forName:@"ToggleQueueTitleTransformer"];
}


- (void)initDefaults
{
	NSDictionary *defaultsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithInteger:RepeatNone], @"repeat",
										[NSNumber numberWithInteger:ShuffleOff],  @"shuffle",
										nil];

	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDictionary];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];

	if (self)
	{
		shuffleList = [[NSMutableArray alloc] init];
		queueList = [[NSMutableArray alloc] init];

        undoManager = [[NSUndoManager alloc] init];

        [undoManager setLevelsOfUndo:UNDO_STACK_LIMIT];

		[self initDefaults];
	}

	return self;
}


- (void)dealloc
{
	[shuffleList release];
	[queueList release];

    [undoManager release];

	[super dealloc];
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	[self addObserver:self forKeyPath:@"arrangedObjects" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"arrangedObjects"])
	{
		[self updatePlaylistIndexes];
	}
}

- (void)updatePlaylistIndexes
{
	int i;
	NSArray *arranged = [self arrangedObjects];
	for (i = 0; i < [arranged count]; i++)
	{
		PlaylistEntry *pe = [arranged objectAtIndex:i];
		if (pe.index != i) //Make sure we don't get into some kind of crazy observing loop...
			pe.index = i;
	}
}

- (void)tableView:(NSTableView *)tableView
		didClickTableColumn:(NSTableColumn *)tableColumn
{
	if ([self shuffle] != ShuffleOff)
		[self resetShuffleList];
}

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc row:(int)row mouseLocation:(NSPoint)mouseLocation
{
	DLog(@"GETTING STATUS FOR ROW: %i: %@!", row, [[[self arrangedObjects] objectAtIndex:row] statusMessage]);
	return [[[self arrangedObjects] objectAtIndex:row] statusMessage];
}

-(void)moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)indexSet
										toIndex:(unsigned int)insertIndex
{
	[super moveObjectsInArrangedObjectsFromIndexes:indexSet toIndex:insertIndex];

	NSUInteger lowerIndex = insertIndex;
	NSUInteger index = insertIndex;

	while (NSNotFound != lowerIndex) {
		lowerIndex = [indexSet indexLessThanIndex:lowerIndex];

		if (lowerIndex != NSNotFound)
			index = lowerIndex;
	}

	[playbackController playlistDidChange:self];
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	[super tableView:aTableView writeRowsWithIndexes:rowIndexes toPasteboard:pboard];

	NSMutableArray *filenames = [NSMutableArray array];
	NSInteger row;
	for (row = [rowIndexes firstIndex];
		 row <= [rowIndexes lastIndex];
		 row = [rowIndexes indexGreaterThanIndex:row])
	{
		PlaylistEntry *song = [[self arrangedObjects] objectAtIndex:row];
		[filenames addObject:[[song path] stringByExpandingTildeInPath]];
	}

	[pboard addTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:self];
    [pboard setPropertyList:filenames forType:NSFilenamesPboardType];

	return YES;
}

- (BOOL)tableView:(NSTableView*)tv
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)op
{
	//Check if DNDArrayController handles it.
	if ([super tableView:tv acceptDrop:info row:row dropOperation:op])
		return YES;

	if (row < 0)
		row = 0;


	// Determine the type of object that was dropped
	NSArray *supportedTypes = [NSArray arrayWithObjects:CogUrlsPboardType, NSFilenamesPboardType, iTunesDropType, nil];
	NSPasteboard *pboard = [info draggingPasteboard];
	NSString *bestType = [pboard availableTypeFromArray:supportedTypes];

	NSMutableArray *acceptedURLs = [[NSMutableArray alloc] init];

	// Get files from an file drawer drop
	if ([bestType isEqualToString:CogUrlsPboardType]) {
		NSArray *urls = [NSUnarchiver unarchiveObjectWithData:[[info draggingPasteboard] dataForType:CogUrlsPboardType]];
		DLog(@"URLS: %@", urls);
		//[playlistLoader insertURLs: urls atIndex:row sort:YES];
		[acceptedURLs addObjectsFromArray:urls];
	}

	// Get files from a normal file drop (such as from Finder)
	if ([bestType isEqualToString:NSFilenamesPboardType]) {
		NSMutableArray *urls = [[NSMutableArray alloc] init];

		for (NSString *file in [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType])
		{
			[urls addObject:[NSURL fileURLWithPath:file]];
		}

		//[playlistLoader insertURLs:urls atIndex:row sort:YES];
		[acceptedURLs addObjectsFromArray:urls];
		[urls release];
	}

	// Get files from an iTunes drop
	if ([bestType isEqualToString:iTunesDropType]) {
		NSDictionary *iTunesDict = [pboard propertyListForType:iTunesDropType];
		NSDictionary *tracks = [iTunesDict valueForKey:@"Tracks"];

		// Convert the iTunes URLs to URLs....MWAHAHAH!
		NSMutableArray *urls = [[NSMutableArray alloc] init];

		for (NSDictionary *trackInfo in [tracks allValues]) {
			[urls addObject:[NSURL URLWithString:[trackInfo valueForKey:@"Location"]]];
		}

		//[playlistLoader insertURLs:urls atIndex:row sort:YES];
		[acceptedURLs addObjectsFromArray:urls];
		[urls release];
	}

	if ([acceptedURLs count])
	{
		[self willInsertURLs:acceptedURLs origin:URLOriginInternal];

		if (![[self content] count]) {
			row = 0;
		}

		NSArray* entries = [playlistLoader insertURLs:acceptedURLs atIndex:row sort:YES];
		[self didInsertURLs:entries origin:URLOriginInternal];
	}

	[acceptedURLs release];

	if ([self shuffle] != ShuffleOff)
		[self resetShuffleList];

	return YES;
}

- (NSUndoManager *)undoManager
{
	return undoManager;
}

- (void)insertObjects:(NSArray *)objects atArrangedObjectIndexes:(NSIndexSet *)indexes
{
    [[[self undoManager] prepareWithInvocationTarget:self] removeObjectsAtArrangedObjectIndexes:indexes];
    NSString *actionName = [NSString stringWithFormat:@"Adding %d entries", [objects count]];
    [[self undoManager] setActionName:actionName];

    [super insertObjects:objects atArrangedObjectIndexes:indexes];

    if ([self shuffle] != ShuffleOff)
        [self resetShuffleList];
}

- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes
{
    NSArray *objects = [[self content] objectsAtIndexes:indexes];
    [[[self undoManager] prepareWithInvocationTarget:self] insertObjects:objects atArrangedObjectIndexes:indexes];
    NSString *actionName = [NSString stringWithFormat:@"Removing %d entries", [indexes count]];
    [[self undoManager] setActionName:actionName];

    DLog(@"Removing indexes: %@", indexes);
    DLog(@"Current index: %i", currentEntry.index);

    if (currentEntry.index >= 0 && [indexes containsIndex:currentEntry.index])
    {
        currentEntry.index = -currentEntry.index - 1;
        DLog(@"Current removed: %i", currentEntry.index);
    }

    if (currentEntry.index < 0) //Need to update the negative index
    {
        int i = -currentEntry.index - 1;
        DLog(@"I is %i", i);
        int j;
        for (j = i - 1; j >= 0; j--)
        {
            if ([indexes containsIndex:j]) {
                DLog(@"Removing 1");
                i--;
            }
        }
        currentEntry.index = -i - 1;

    }

    [super removeObjectsAtArrangedObjectIndexes:indexes];

    if ([self shuffle] != ShuffleOff)
        [self resetShuffleList];

    [playbackController playlistDidChange:self];
}

- (void)setSortDescriptors:(NSArray *)sortDescriptors
{

}

- (IBAction)toggleShuffle:(id)sender
{
	ShuffleMode shuffle = [self shuffle];

	if (shuffle == ShuffleOff) {
		[self setShuffle: ShuffleAlbums];
	}
	else if (shuffle == ShuffleAlbums) {
		[self setShuffle: ShuffleAll];
	}
	else if (shuffle == ShuffleAll) {
		[self setShuffle: ShuffleOff];
	}
}

- (IBAction)toggleRepeat:(id)sender
{
	RepeatMode repeat = [self repeat];

	if (repeat == RepeatNone) {
		[self setRepeat: RepeatAll];
	}
	else if (repeat == RepeatAll) {
		[self setRepeat: RepeatNone];
	}
}

- (PlaylistEntry *)entryAtIndex:(int)i
{
	RepeatMode repeat = [self repeat];

	if (i < 0)
	{
		if (repeat != RepeatNone)
			i += [[self arrangedObjects] count];
		else
			return nil;
	}
	else if (i >= [[self arrangedObjects] count])
	{
		if (repeat != RepeatNone)
			i -= [[self arrangedObjects] count];
		else
			return nil;
	}

	return [[self arrangedObjects] objectAtIndex:i];
}

- (void)remove:(id)sender {
    // It's a kind of magic.
    // Plain old NSArrayController's remove: isn't working properly for some reason.
    // The method is definitely called but (overridden) removeObjectsAtArrangedObjectIndexes: isn't called
    // and no entries are removed.
    // Putting explicit call to removeObjectsAtArrangedObjectIndexes: here for now.
    // TODO: figure it out

    NSIndexSet *selected = [self selectionIndexes];
    if ([selected count] > 0)
    {
        [self removeObjectsAtArrangedObjectIndexes:selected];
    }
}

- (PlaylistEntry *)shuffledEntryAtIndex:(int)i
{
	RepeatMode repeat = [self repeat];

	while (i < 0)
	{
		if (repeat == RepeatAll)
		{
			[self addShuffledListToFront];
			//change i appropriately
			i += [[self arrangedObjects] count];
		}
		else
		{
			return nil;
		}
	}
	while (i >= [shuffleList count])
	{
		if (repeat == RepeatAll)
		{
			[self addShuffledListToBack];
		}
		else
		{
			return nil;
		}
	}

	return [shuffleList objectAtIndex:i];
}

- (PlaylistEntry *)getNextEntry:(PlaylistEntry *)pe
{
	if ([queueList count] > 0)
	{

		pe = [queueList objectAtIndex:0];
		[queueList removeObjectAtIndex:0];
		pe.queued = NO;
		[pe setQueuePosition:-1];

		int i;
		for (i = 0; i < [queueList count]; i++)
		{
			PlaylistEntry *queueItem = [queueList objectAtIndex:i];
			[queueItem setQueuePosition: i];
		}

		return pe;
	}

	if ([self shuffle] != ShuffleOff)
	{
		return [self shuffledEntryAtIndex:(pe.shuffleIndex + 1)];
	}
	else
	{
		int i;
		if (pe.index < 0) //Was a current entry, now removed.
		{
			i = -pe.index - 1;
		}
		else
		{
			i = pe.index + 1;
		}

		return [self entryAtIndex:i];
	}
}

- (NSArray *)filterPlaylistOnAlbum:(NSString *)album
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"album like %@",
							  album];
	return [[self arrangedObjects] filteredArrayUsingPredicate:predicate];
}

- (PlaylistEntry *)getPrevEntry:(PlaylistEntry *)pe
{
	if ([self shuffle] != ShuffleOff)
	{
		return [self shuffledEntryAtIndex:(pe.shuffleIndex - 1)];
	}
	else
	{
		int i;
		if (pe.index < 0) //Was a current entry, now removed.
		{
			i = -pe.index - 2;
		}
		else
		{
			i = pe.index - 1;
		}

		return [self entryAtIndex:i];
	}
}

- (BOOL)next
{
	PlaylistEntry *pe;

	pe = [self getNextEntry:[self currentEntry]];

	if (pe == nil)
		return NO;

	[self setCurrentEntry:pe];

	return YES;
}

- (BOOL)prev
{
	PlaylistEntry *pe;

	pe = [self getPrevEntry:[self currentEntry]];
	if (pe == nil)
		return NO;

	[self setCurrentEntry:pe];

	return YES;
}

- (void)addShuffledListToFront
{
	NSArray *newList = [Shuffle shuffleList:[self arrangedObjects]];
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [newList count])];

	[shuffleList insertObjects:newList atIndexes:indexSet];

	int i;
	for (i = 0; i < [shuffleList count]; i++)
	{
		[[shuffleList objectAtIndex:i] setShuffleIndex:i];
	}
}

- (void)addShuffledListToBack
{
	NSArray *newList = [Shuffle shuffleList:[self arrangedObjects]];
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([shuffleList count], [newList count])];

	[shuffleList insertObjects:newList atIndexes:indexSet];

	int i;
	for (i = ([shuffleList count] - [newList count]); i < [shuffleList count]; i++)
	{
		[[shuffleList objectAtIndex:i] setShuffleIndex:i];
	}
}

- (void)resetShuffleList
{
	[shuffleList removeAllObjects];

	[self addShuffledListToFront];

	if (currentEntry && currentEntry.index >= 0)
	{
		[shuffleList insertObject:currentEntry atIndex:0];
		[currentEntry setShuffleIndex:0];

		//Need to rejigger so the current entry is at the start now...
		int i;
		BOOL found = NO;
		for (i = 1; i < [shuffleList count] && !found; i++)
		{
			if ([shuffleList objectAtIndex:i] == currentEntry)
			{
				found = YES;
				[shuffleList removeObjectAtIndex:i];
			}
			else {
				[[shuffleList objectAtIndex:i] setShuffleIndex: i];
			}
		}
	}
}

- (void)setCurrentEntry:(PlaylistEntry *)pe
{

    if (![pe metadataLoaded]) {
        // Force loading metadata if it isn't loaded,
        // will hopefully prevent
        // non-updating progress slider and wrong remaining time
        DLog(@"Metadata isn't loaded for %@", [pe description]);
        NSDictionary *metadata = [playlistLoader readEntryInfo:pe];
        [pe setMetadata:metadata];
    }

	currentEntry.current = NO;

	pe.current = YES;

	if (pe != nil)
		[tableView scrollRowToVisible:pe.index];

	[pe retain];
	[currentEntry release];

	currentEntry = pe;
}

- (void)setShuffle:(ShuffleMode)s
{
	[[NSUserDefaults standardUserDefaults] setInteger:s forKey:@"shuffle"];
	if (s != ShuffleOff)
		[self resetShuffleList];

	[playbackController playlistDidChange:self];
}
- (ShuffleMode)shuffle
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:@"shuffle"];
}
- (void)setRepeat:(RepeatMode)r
{
	[[NSUserDefaults standardUserDefaults] setInteger:r forKey:@"repeat"];
	[playbackController playlistDidChange:self];
}
- (RepeatMode)repeat
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:@"repeat"];
}

- (IBAction)clear:(id)sender
{
	[self setFilterPredicate:nil];

	[self removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[self arrangedObjects] count])]];
}

- (IBAction)clearFilterPredicate:(id)sender
{
	[self setFilterPredicate:nil];
}

- (void)setFilterPredicate:(NSPredicate *)filterPredicate
{
	[super setFilterPredicate:filterPredicate];
}

- (IBAction)showEntryInFinder:(id)sender
{
	NSWorkspace* ws = [NSWorkspace sharedWorkspace];
	if (NSNotFound == [self selectionIndex])
		return;

	NSURL *url = [[[self selectedObjects] objectAtIndex:0] URL];
	if ([url isFileURL])
		[ws selectFile:[url path] inFileViewerRootedAtPath:[url path]];
}

- (NSMutableArray *)queueList
{
	return queueList;
}

- (IBAction)emptyQueueList:(id)sender
{
	for (PlaylistEntry *queueItem in queueList)
	{
		queueItem.queued = NO;
		[queueItem setQueuePosition:-1];
	}

	[queueList removeAllObjects];
}


- (IBAction)toggleQueued:(id)sender
{
	for (PlaylistEntry *queueItem in [self selectedObjects])
	{
		if (queueItem.queued)
		{
			queueItem.queued = NO;
			queueItem.queuePosition = -1;

			[queueList removeObject:queueItem];
		}
		else
		{
			queueItem.queued = YES;
			queueItem.queuePosition = [queueList count];

			[queueList addObject:queueItem];
		}

		DLog(@"TOGGLE QUEUED: %i", queueItem.queued);
	}

	int i = 0;
	for (PlaylistEntry *cur in queueList)
	{
		cur.queuePosition = i++;
	}
}

-(BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
	SEL action = [menuItem action];

	if (action == @selector(removeFromQueue:))
	{
		for (PlaylistEntry *q in [self selectedObjects])
			if (q.queuePosition >= 0)
				return YES;

		return NO;
	}

	if (action == @selector(emptyQueueList:) && ([queueList count] < 1))
		return NO;

	// if nothing is selected, gray out these
	if ([[self selectedObjects] count] < 1)
	{

		if (action == @selector(remove:))
			return NO;

		if (action == @selector(addToQueue:))
			return NO;
	}

	return YES;
}

// Event inlets:
- (void)willInsertURLs:(NSArray*)urls origin:(URLOrigin)origin
{
	if (![urls count])
		return;

	[self clear:self];
}

- (void)didInsertURLs:(NSArray*)urls origin:(URLOrigin)origin
{
	if (![urls count])
		return;

	//Auto start playback
	if ([[self content] count] > 0) {
		[playbackController playEntry: [urls objectAtIndex:0]];
	}
}

@end
