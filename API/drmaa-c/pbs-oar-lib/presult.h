

// La liste des types possibles pour les variables qui seront stockés dans la structure "presult"
enum{
   UNKNOWN,
   INTEGER,
   FLOAT,
   STRING,
   COMPLEX	// Pour dire qu'il s'agit d'un "Object" ou d'un "Array"
};

 
// Element de base
struct element_
{
    char* key;
    int type;			// Le type de la variable  (il est égal à UNKNOWN à la création)
    union {
       int i;
       float f;
       char* s;
    } immValue; 		// Pour les valeurs immédiates (type != UNKNOWN)
    struct element_ *compValue; // Pour les valeurs contenant plusieurs elements (comme la liste des evènements ou la liste des noeuds occupés dans le cas d'un job)
    struct element_ *next;	// Il est égal à NULL à la création vu qu'on ajoute les nouveaux elements en queue de liste
};

// Pour ne pas mettre les struct
typedef struct element_ presult;



// La liste chainée contenant les résultats du parsing
//typedef element* presult;

// Les fonctions
presult* addElement();
void showResult();
void showResult_();
int isEmpty();
presult deleteElement();
presult findElement();
presult findElementNumber();
void removeResult();
void getDrmaaState();
