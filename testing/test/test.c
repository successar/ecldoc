#include <iostream>
#include <string>
using namespace std;

const char * skipWhitespace(const char * text)
{
    while ((*text==' ') || (*text=='\t'))
        text++;
    return text;
}

const char * skipAsterisk(const char * text)
{
    if (*text=='*')
        return skipWhitespace(text+1);
    return text;
}

const char * skipToNewline(const char * text)
{
    while (*text && (*text != '\r') && (*text != '\n') && (*text != ' ') && (*text != '\t'))
        text++;
    return text;
}

const char * skipNewline(const char * text)
{
    if (*text == '\r')
        text++;
    if (*text == '\n')
        text++;
    return text;
}

void extractJavadoc(const char * text)
{
    //Skip a leading blank line
    text = skipWhitespace(text);
    text = skipNewline(text);
    text = skipAsterisk(text);
    //Now process each of the parameters...
    string tagname;
    string tagtext;
    for (;;)
    {
        text = skipWhitespace(text);
        const char * start = text;
        text = skipNewline(text);
        if(start != text)
            text = skipAsterisk(text);
        if ((*text == 0) || (*text == '@'))
        {
            if (tagtext.length())
            {
                if (tagname.length())
                    cout << "@" << tagname << " " << tagtext << endl;
                else
                    cout << "@" << tagtext << endl;
                tagtext.clear();
            }

            if (*text == 0)
                return;

            text++;
            start = text;
            while (isalnum(*text))
                text++;
            if (start != text)
                tagname.clear();
                tagname.append(start, text-start);
            text = skipWhitespace(text);
        }
        start = text;
        text = skipToNewline(text);
        if (start != text)
        {
            if (tagtext.length())
                tagtext.append(" ");
            tagtext.append(start, text-start);
        }
    }
}

int main() {
    const char * jdoc = "*\n* Tests for Type SYstem    tabbed\n*   abnc\n*@param first     first number   \n* of doc\n*@param second dumber";
    extractJavadoc(jdoc);
    return 0;
}