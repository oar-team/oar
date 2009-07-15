 
// Element de base
struct element_
{
    char* key;
    char* immValue; 		// Pour les valeurs immédiates (les strings)
    struct element_ *compValue; // Pour les valeurs contenant plusieurs elements (comme la liste des evènements ou la liste des noeuds occupés dans le cas d'un job)
    struct element_ *next;
};

// Pour ne pas mettre les struct
typedef struct element_ element;

// La liste chainée contenant les résultats du parsing
typedef element* presult;

