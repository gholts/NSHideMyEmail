// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hugo Lee

@import AppKit;
@import UniformTypeIdentifiers;
#include <dlfcn.h>
#include <getopt.h>
#include <unistd.h>

@interface NSObject (NSHideMyEmail)
+ (instancetype)sharedInstance;
- (NSString *)altDSIDforPrimaryiCloudAccount;
- (instancetype)initWithKey:(NSString *)key altDSID:(NSString *)altDSID originType:(NSString *)originType originIdentifier:(NSString *)originIdentifier;
- (void)setHostWindow:(NSWindow *)window;
- (void)presentPrivateEmailUIForContext:(id)context completion:(void (^)(id, NSError *))completion;
- (void)dismiss;
- (NSString *)privateEmailAddress;
@end

static NSString *label;
static BOOL copyResult;
static int status = 1;

static NSError *failure(NSString *message) {
    return [NSError errorWithDomain:@"NSHideMyEmail" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

static NSString *validLabel(NSString *value) {
    value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return value.length && [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound ? value : nil;
}

static NSString *primaryAltDSID(void) {
    NSString *identifier = NSProcessInfo.processInfo.environment[@"HME_ALT_DSID"];
    if (identifier.length) return identifier;
    id manager = [NSClassFromString(@"AKAccountManager") sharedInstance];
    identifier = [manager respondsToSelector:@selector(altDSIDforPrimaryiCloudAccount)] ? [manager altDSIDforPrimaryiCloudAccount] : nil;
    if ([identifier isKindOfClass:NSString.class] && identifier.length) return identifier;
    NSURL *url = [NSFileManager.defaultManager.homeDirectoryForCurrentUser URLByAppendingPathComponent:@"Library/Preferences/MobileMeAccounts.plist"];
    NSArray *accounts = [NSDictionary dictionaryWithContentsOfURL:url error:nil][@"Accounts"];
    if (![accounts isKindOfClass:NSArray.class] || accounts.count != 1 || ![accounts.firstObject isKindOfClass:NSDictionary.class]) return nil;
    identifier = accounts.firstObject[@"AccountAlternateDSID"];
    return [identifier isKindOfClass:NSString.class] && identifier.length ? identifier : nil;
}

static NSAlert *newAlert(void) {
    NSAlert *alert = [NSAlert new];
    UTType *type = [UTType typeWithIdentifier:@"com.apple.graphic-icon.hide-my-email"];
    if (type.isDeclared) alert.icon = [NSWorkspace.sharedWorkspace iconForContentType:type];
    return alert;
}

static NSString *promptLabel(void) {
    NSAlert *alert = newAlert();
    alert.messageText = @"New Hide My Email Address";
    [alert addButtonWithTitle:@"Continue"];
    [alert addButtonWithTitle:@"Cancel"];
    NSTextField *field = [NSTextField textFieldWithString:@""];
    field.placeholderString = @"Label";
    field.frame = NSMakeRect(0, 0, 240, 24);
    alert.accessoryView = field;
    alert.window.initialFirstResponder = field;
    while ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *value = validLabel(field.stringValue);
        if (value) return value;
    }
    return nil;
}

@interface HostWindow : NSWindow
@end

@implementation HostWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

@interface Creator : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) id provider;
@end

@implementation Creator

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp activateIgnoringOtherApps:YES];
    if (!label && !(label = promptLabel())) {
        [NSApp terminate:nil];
        return;
    }

    NSRect screen = NSScreen.mainScreen.visibleFrame;
    self.window = [[HostWindow alloc] initWithContentRect:NSMakeRect(NSMidX(screen), NSMidY(screen) + 225, 1, 1)
        styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    self.window.opaque = NO;
    self.window.backgroundColor = NSColor.clearColor;
    self.window.hasShadow = NO;
    self.window.releasedWhenClosed = NO;
    [self.window makeKeyAndOrderFront:nil];

    NSError *error;
    if (![self present:&error]) [self fail:error];
}

- (BOOL)present:(NSError **)error {
    void *authKit = dlopen("/System/Library/PrivateFrameworks/AuthKit.framework/AuthKit", RTLD_NOW);
    void *authKitUI = dlopen("/System/Library/PrivateFrameworks/AuthKitUI.framework/AuthKitUI", RTLD_NOW);
    NSString *const __unsafe_unretained *origin = authKit ? (NSString *const __unsafe_unretained *)dlsym(authKit, "AKPrivateEmailOriginTypeThirdPartyApp") : NULL;
    Class contextClass = NSClassFromString(@"AKPrivateEmailContext");
    Class providerClass = NSClassFromString(@"AKPrivateEmailUIProviderImp");
    if (!authKitUI || !origin || !*origin ||
        ![contextClass instancesRespondToSelector:@selector(initWithKey:altDSID:originType:originIdentifier:)] ||
        ![providerClass instancesRespondToSelector:@selector(setHostWindow:)] ||
        ![providerClass instancesRespondToSelector:@selector(presentPrivateEmailUIForContext:completion:)] ||
        ![providerClass instancesRespondToSelector:@selector(dismiss)]) {
        *error = failure(@"Hide My Email isn't available on this version of macOS.");
        return NO;
    }
    NSString *identifier = primaryAltDSID();
    if (!identifier.length) {
        *error = failure(@"Sign in to iCloud on this Mac to use Hide My Email.");
        return NO;
    }
    id context = [[contextClass alloc] initWithKey:label altDSID:identifier originType:*origin originIdentifier:label];
    if (!context) {
        *error = failure(@"AuthKit rejected the request.");
        return NO;
    }

    id provider = [providerClass new];
    [provider setHostWindow:self.window];
    self.provider = provider;
    __weak Creator *weakSelf = self;
    __weak id weakProvider = provider;
    [provider presentPrivateEmailUIForContext:context completion:^(id email, NSError *nativeError) {
        NSString *address = [email respondsToSelector:@selector(privateEmailAddress)] ? [[email privateEmailAddress] copy] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            Creator *owner = weakSelf;
            if (!owner || !weakProvider || owner.provider != weakProvider) return;
            owner.provider = nil;
            if (address.length) [owner succeed:address];
            else if ([nativeError.domain isEqual:@"AKAuthenticationError"] && nativeError.code == -7003) [NSApp terminate:nil];
            else [owner fail:nativeError ?: failure(@"Apple finished without returning an address.")];
        });
    }];
    return YES;
}

- (void)succeed:(NSString *)address {
    if (copyResult) {
        [NSPasteboard.generalPasteboard clearContents];
        [NSPasteboard.generalPasteboard setString:address forType:NSPasteboardTypeString];
    }
    puts(address.UTF8String);
    fflush(stdout);
    status = 0;
    [NSApp terminate:nil];
}

- (void)fail:(NSError *)error {
    fprintf(stderr, "hme: %s (%s %ld)\n", error.localizedDescription.UTF8String, error.domain.UTF8String, (long)error.code);
    if (isatty(STDERR_FILENO)) {
        [NSApp terminate:nil];
        return;
    }
    NSAlert *alert = newAlert();
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Couldn't create a Hide My Email address";
    alert.informativeText = [NSString stringWithFormat:@"%@\n\n%@ %ld", error.localizedDescription, error.domain, (long)error.code];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        [NSApp terminate:nil];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    id provider = self.provider;
    self.provider = nil;
    [provider dismiss];
    exit(status);
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        int option;
        while ((option = getopt(argc, argv, "ch")) != -1) {
            if (option == 'c') {
                copyResult = YES;
            } else {
                fputs("usage: hme [-c] [label]\n"
                      "  Opens Apple's Hide My Email sheet and prints the new address.\n"
                      "  -c  also copy the address to the clipboard\n"
                      "  Without a label, hme asks for one.\n", option == 'h' ? stdout : stderr);
                return option == 'h' ? 0 : 2;
            }
        }
        if (optind < argc) {
            NSMutableArray *words = [NSMutableArray array];
            for (int index = optind; index < argc; index++) [words addObject:@(argv[index])];
            if (!(label = validLabel([words componentsJoinedByString:@" "]))) {
                fputs("hme: the label must be one non-empty line\n", stderr);
                return 2;
            }
        }
        Creator *creator = [Creator new];
        NSApplication.sharedApplication.delegate = creator;
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp run];
    }
    return status;
}
