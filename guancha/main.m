//
//  main.m
//  guancha
//
//  Created by duanqinglun on 15/11/27.
//  Copyright © 2015年 duanqinglun. All rights reserved.
//

#import <Foundation/Foundation.h>

#define HOST @"http://www.guancha.cn"

NSXMLDocument *_document;
NSXMLNode *_bodyNode;
NSXMLNode *_mainNode;
NSArray<NSXMLNode *> *_currentList;

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
        NSXMLNode *attr = [element attributeForName:attributeName];
        BOOL match = NO;
        if (!allowPartial && [attr.stringValue isEqualToString:attributeValue])
            match = YES;
        else if (allowPartial && [attr.stringValue containsString:attributeValue])
            match = YES;
        if (match)
            return node;
        
        NSXMLNode *cNode = findChildWithAttribute(attributeName, attributeValue, node, allowPartial);
        if (cNode != nil)
            return cNode;
    }
    return nil;
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

int load(NSURL *url)
{
    NSError *error = nil;
    _document = [[NSXMLDocument alloc] initWithContentsOfURL:url?:[NSURL URLWithString:HOST] options:NSXMLDocumentTidyHTML error:&error];
    if (!_document && error) {
        printf("error:\n%s\n", error.localizedDescription.UTF8String);
        return EXIT_FAILURE;
    }
    _bodyNode = findChildWithTag(@"body", _document)[0];
    _mainNode = findChildWithAttribute(@"class", @"main-contain", _bodyNode, YES);
    return EXIT_SUCCESS;
}

void view(int index)
{
    NSXMLNode *node = _currentList[index];
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:[node childAtIndex:0].XMLString error:NULL];
    NSXMLNode *hrefAttr = [element attributeForName:@"href"];
    NSString *urlString = hrefAttr.stringValue;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", HOST, urlString]];
    load(url);
}

void list(NSString *class, NSString *tag)
{
    NSXMLNode *theNode = findChildWithAttribute(@"class", class, _mainNode, YES);
    _currentList = findChildWithTag(tag, theNode);
    for (int i = 0; i < _currentList.count; i++) {
        NSXMLNode *titleNode = _currentList[i];
        printf("%d %s\n", i, titleNode.stringValue.UTF8String);
    }
}

void extractOperationAndArg(char *line, char *operation, char *arg)
{
    
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
        } else if (strstr(line, "view") != NULL) {
            int index = 0;
            view(index);
        } else if (strcmp(line, "q") == 0) {
            break;
        } else {
            showStruct(_document);
        }
    }
    if (line)
        free(line);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (load(nil) == EXIT_FAILURE) {
            return EXIT_FAILURE;
        }
        
        printf("usage:\n");
        waitingForInput();
    }
}