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

#pragma mark - parseHTML

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

#pragma mark - load

#define HOST @"http://www.guancha.cn"

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

#pragma mark - handle text

#define TAB_WIDTH 4

typedef struct
{
    int width;
    int height;
} SIZE;

typedef struct
{
    char *str;
} LINE;

typedef struct
{
    LINE *text;
    int nunberOfLines;
} TEXT;

void initLINE(LINE *l, char *str)
{
    l->str = (char *)malloc(strlen(str) * sizeof(char));
    strcpy(l->str, str);
}

void initTEXT(TEXT *t, const char *content, SIZE size)
{
    NSString *contentStr = [NSString stringWithUTF8String:content];
    NSMutableString *strInLine = [[NSMutableString alloc] init];
    int indexOfLine = 0;
    
    for (int i = 0; i < contentStr.length; i++) {
        NSString *strAtIndex = [contentStr substringWithRange:NSMakeRange(i, 1)];
        if ([strAtIndex isEqualToString:@"\n"]) {
            LINE *tmp = (LINE *)malloc((indexOfLine + 1) * sizeof(LINE));
            for (int l = 0; l < indexOfLine; l++) {
                tmp[l] = t->text[l];
            }
            initLINE(tmp + indexOfLine, (char *)[strInLine UTF8String]);
            if (t->nunberOfLines > 0) {
                free(t->text);
            }
            t->text = tmp;
            [strInLine setString:@""];
            indexOfLine++;
            t->nunberOfLines = indexOfLine;
        } else if (strInLine.length < size.width) {
            [strInLine appendString:strAtIndex];
        } else {
            LINE *tmp = (LINE *)malloc((indexOfLine + 1) * sizeof(LINE));
            for (int l = 0; l < indexOfLine; l++) {
                tmp[l] = t->text[l];
            }
            initLINE(tmp + indexOfLine, (char *)[strInLine UTF8String]);
            if (t->nunberOfLines > 0) {
                free(t->text);
            }
            t->text = tmp;
            [strInLine setString:@""];
            indexOfLine++;
            t->nunberOfLines = indexOfLine;
            [strInLine appendString:strAtIndex];
        }
    }
}

void printTEXT(WINDOW *win, const TEXT *t, int start, int end)
{
    int indexOfLineInTEXT, indexOfLineInWin;
    for(indexOfLineInTEXT = start, indexOfLineInWin = 0; indexOfLineInTEXT < end; indexOfLineInTEXT++, indexOfLineInWin++)
    {
        wmove(win, indexOfLineInWin, 0);
        wclrtoeol(win);
        
        if (start_color() == OK) { /*开启颜色*/
            init_pair(1, COLOR_WHITE, COLOR_BLUE); /*建立一个颜色对*/
            wattron(win, COLOR_PAIR(1)); /*开启字符输出颜色*/
            waddstr(win, t->text[indexOfLineInTEXT].str); /*输出字符到标准屏幕上*/
            wattroff(win, COLOR_PAIR(1)); /*关闭颜色显示*/
        } else {
            waddstr(win, t->text[indexOfLineInTEXT].str);
        }
    }
    wrefresh(win);
}

void newView(const char *content)
{
    setlocale(LC_ALL,"");
    initscr(); /*初始化屏幕*/
    //完成initscr后，输入模式为预处理模式，（1）所有处理是基于行的，就是说，只有按下回车，输入数据才被传给程序；（2）键盘特殊字符启用，按下合适组合键会产生信号
    cbreak(); /*设置cbreak模式，字符一键入，直接传给程序*/
    noecho(); /*让输入不会显示在屏幕上*/
    nonl();
//    curs_set(0); /*隐藏光标*/
    clear();
    
    WINDOW *win = newwin(LINES-3, COLS-4, 2, 2);
    wborder(win, 1, 1, 1, 1, 1, 1, 1, 1);
    keypad(win, TRUE); /*开启后可以处理‘\’转义字符开头的逻辑键*/
    
    init_pair(0, COLOR_GREEN, COLOR_WHITE);
    init_pair(1, COLOR_WHITE, COLOR_BLACK);
    wbkgd(win,0);
    bkgd(1);
    
    scrollok(win, TRUE);
    box(stdscr, ACS_VLINE, ACS_HLINE);
    refresh();
    
    TEXT text;
    initTEXT(&text, content, (SIZE){25, 22});
    int numberOfLinesCanShow = 22;
    int firstLineY = 0;
    int indexOfWin1stLineInTEXT = 0;

//    setscrreg(0, LINES);
    mvwaddstr(stdscr, 1, 1, "按q键返回");
    
    printTEXT(win, &text, indexOfWin1stLineInTEXT, indexOfWin1stLineInTEXT + numberOfLinesCanShow-1);

    touchwin(win); /*转换当前窗口为win*/
    wnoutrefresh(win);
    int ch, x, y;
    getyx(win, y, x); /*获得当前逻辑光标位置*/
    do {
        ch = getch();
//        waddch(win, ch);
        switch(ch)
        {
            case 65:
                if (y > firstLineY) {
                    y--;
                } else if (indexOfWin1stLineInTEXT > 0) {
                    indexOfWin1stLineInTEXT--;
                    printTEXT(win, &text, indexOfWin1stLineInTEXT, indexOfWin1stLineInTEXT + numberOfLinesCanShow-1);
                }
                break;
            case 66:
                if (y < firstLineY + numberOfLinesCanShow - 1) {
                    y++;
                } else if (indexOfWin1stLineInTEXT < text.nunberOfLines-1) {
                    indexOfWin1stLineInTEXT++;
                    printTEXT(win, &text, indexOfWin1stLineInTEXT, indexOfWin1stLineInTEXT + numberOfLinesCanShow-1);
                }
                break;
            default:
                break;
        }
        wmove(win, y, x);
        wrefresh(win);
    } while (ch != 'q');
    endwin(); /*关闭curses状态,恢复到原来的屏幕*/
}

#pragma mark - control

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
    
//    TEXT text;
//    initTEXT(&text, _mainNode.stringValue.UTF8String, (SIZE){25, 22});
//    for(int i = 0; i < text.nunberOfLines; i++) {
//        printf("%s\n", text.text[i].str);
//    }
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
        
//        list(@"page-1st-column", @"h4");
//        view(1);
    }
}