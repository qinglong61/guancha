//
//  main.m
//  guancha
//
//  Created by duanqinglun on 15/11/27.
//  Copyright © 2015年 duanqinglun. All rights reserved.
//

#import <Foundation/Foundation.h>

#define URL [NSURL URLWithString:@"http://www.guancha.cn"]

NSXMLDocument *document;
NSXMLNode *bodyNode;
NSXMLNode *mainNode;

NSArray<NSXMLNode *> *findChildWithTag(NSString *tagName, NSXMLNode *inXMLNode)
{
	NSMutableArray *array = [NSMutableArray array];
    for (NSXMLNode *node in inXMLNode.children) {
        if ([node.name isEqualToString:tagName]) {
            [array addObject:node];
        }
        NSArray *nodes = findChildWithTag(tagName, node);
        if (nodes != nil) {
            [array addObjectsFromArray:nodes];
        }
    }
    if (array.count == 0) {
        return nil;
    }
    return array;
}

NSXMLNode *findChildWithAttribute(NSString *attributeName, NSString *attributeValue, NSXMLNode *inXMLNode, BOOL allowPartial)
{
    if (!inXMLNode)
        return nil;
    
    for (NSXMLNode *node in inXMLNode.children) {
        NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:node.XMLString error:NULL];
        for (NSXMLNode *attr in element.attributes) {
            if ([attr.name isEqualToString:attributeName]) {
                BOOL match = NO;
                if (!allowPartial && [attr.stringValue isEqualToString:attributeValue])
                    match = YES;
                else if (allowPartial && [attr.stringValue containsString:attributeValue])
                    match = YES;
                if (match)
                    return node;
            }
        }
        
        NSXMLNode *cNode = findChildWithAttribute(attributeName, attributeValue, node, allowPartial);
        if (cNode != nil)
            return cNode;
    }
    return nil;
}

void list(NSString *class, NSString *tag)
{
    NSXMLNode *theNode = findChildWithAttribute(@"class", class, mainNode, YES);
    NSArray *titleNodes = findChildWithTag(tag, theNode);
    for (NSXMLNode *titleNode in titleNodes) {
        printf("%s\n", titleNode.stringValue.UTF8String);
    }
}

void showStruct(NSXMLNode *node)
{
    for (int i = 0; i < node.level; i++) {
        printf("-");
    }
    printf("%s\n", node.name.UTF8String);
    for (NSXMLNode *childNode in node.children) {
        showStruct(childNode);
    }
}

void waitingForInput()
{
    char *line = NULL;
    size_t len = 0;
    ssize_t read;
    while ((read = getline(&line, &len, stdin)) != -1)
    {
        if (strcmp(line, "list1\n") == 0) {
            list(@"page-1st-column", @"h4");
        } else if (strcmp(line, "list2\n") == 0) {
            list(@"page-2nd-column", @"h5");
        } else if (strcmp(line, "list3\n") == 0) {
            list(@"right-side01", @"h4");
        } else if (strcmp(line, "q") == 0) {
            break;
        } else {
            showStruct(document);
        }
    }
    if (line)
        free(line);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSError *error = nil;
        document = [[NSXMLDocument alloc] initWithContentsOfURL:URL options:NSXMLDocumentTidyHTML error:&error];
        if (!document && error) {
            printf("error:\n%s\n", error.localizedDescription.UTF8String);
            return EXIT_FAILURE;
        }
        bodyNode = findChildWithTag(@"body", document)[0];
        mainNode = findChildWithAttribute(@"class", @"main-contain", bodyNode, YES);
        
        printf("usage:\n");
        waitingForInput();
    }
}