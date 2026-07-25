#include <chrono>
#include <iostream>

using namespace std;

int main()
{
    cout << chrono::current_zone()->name() << endl;
    return 0;
}
