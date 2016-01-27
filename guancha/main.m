//
//  main.m
//  guancha
//
//  Created by duanqinglun on 15/11/27.
//  Copyright © 2015年 duanqinglun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <curses.h>
#import <locale.h>

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
    if (!url) {
        _mainNode = findChildWithAttribute(@"class", @"main-contain", _bodyNode, YES);
    } else {
        _mainNode = findChildWithAttribute(@"class", @"all-txt", _bodyNode, YES);
    }
    return EXIT_SUCCESS;
}

void newView(const char *content)
{
    setlocale(LC_ALL,"");
    initscr(); /*初始化屏幕*/
    keypad(stdscr, TRUE);
    scrollok(stdscr, TRUE);
    setscrreg(0, LINES);
    waddstr(stdscr, "按q键返回\n\n");
    if (start_color() == OK) /*开启颜色*/
    {
        init_pair(1, COLOR_WHITE, COLOR_BLACK); /*建立一个颜色对*/
        attron(COLOR_PAIR(1)); /*开启字符输出颜色*/
        waddstr(stdscr, content); /*输出字符到标准屏幕上*/
        attroff(COLOR_PAIR(1)); /*关闭颜色显示*/
    }
    else
    {
        waddstr(stdscr, content);
    }
    waddstr(stdscr, "\n\n按q返回");
    refresh(); /*把逻辑屏幕的改动在物理屏幕上显示出来*/
    int c = 0;
    while (c != 'q') { /*让程序停在当前屏幕直到输入q*/
        c = getch();
//        if (c == KEY_UP) {
//            wscrl(stdscr, 1);
//        }
//        ungetch(0);
    }
    endwin(); /*关闭curses状态,恢复到原来的屏幕*/
}

void view(int index)
{
    NSXMLNode *node = _currentList[index];
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:[node childAtIndex:0].XMLString error:NULL];
    NSXMLNode *hrefAttr = [element attributeForName:@"href"];
    NSString *urlString = hrefAttr.stringValue;
    NSString *allTextUrl = [NSString stringWithFormat:@"%@_s.shtml", [urlString substringToIndex:(urlString.length - @".shtml".length)]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", HOST, allTextUrl]];
    load(url);
    
    newView(_mainNode.stringValue.UTF8String);
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

void extractOperationAndArg(char *line, NSString **operation, NSString **arg)
{
    NSString *sline = [NSString stringWithUTF8String:line];
    NSArray *arr = [sline componentsSeparatedByString:@" "];
    *operation = arr[0];
    *arg = arr[1];
}

void showUsage()
{
    printf("用法:\nlist1        显示左侧列表\nlist2        显示中间列表\nlist3        显示右侧列表\nview 序号    显示文章内容\n");
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
            NSString *operation;
            NSString *arg;
            extractOperationAndArg(line, &operation, &arg);
            int index = [arg intValue];
            view(index);
        } else if (strcmp(line, "q\n") == 0) {
            break;
        } else {
            showUsage();
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
        showUsage();
        waitingForInput();
//        newView("测试");
    }
}