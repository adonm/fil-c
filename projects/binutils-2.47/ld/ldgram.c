/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison implementation for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* C LALR(1) parser skeleton written by Richard Stallman, by
   simplifying the original so-called "semantic" parser.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output, and Bison version.  */
#define YYBISON 30802

/* Bison version string.  */
#define YYBISON_VERSION "3.8.2"

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Push parsers.  */
#define YYPUSH 0

/* Pull parsers.  */
#define YYPULL 1




/* First part of user prologue.  */
#line 22 "ldgram.y"

/*

 */

#define DONTDECLARE_MALLOC

#include "sysdep.h"
#include "libiberty.h"
#include "bfd.h"
#include "bfdlink.h"
#include "ctf-api.h"
#include "ld.h"
#include "ldexp.h"
#include "ldver.h"
#include "ldlang.h"
#include "ldfile.h"
#include "ldemul.h"
#include "ldmisc.h"
#include "ldmain.h"
#include "mri.h"
#include "ldctor.h"
#include "ldlex.h"

#ifndef YYDEBUG
#define YYDEBUG 1
#endif

static enum section_type sectype;
static etree_type *sectype_value;
static lang_memory_region_type *region;

static bool ldgram_had_keep = false;
static char *ldgram_vers_current_lang = NULL;

#define ERROR_NAME_MAX 20
static char *error_names[ERROR_NAME_MAX];
static int error_index;
#define PUSH_ERROR(x) if (error_index < ERROR_NAME_MAX) error_names[error_index] = x; error_index++;
#define POP_ERROR()   error_index--;

static void yyerror (const char *);

#line 115 "ldgram.c"

# ifndef YY_CAST
#  ifdef __cplusplus
#   define YY_CAST(Type, Val) static_cast<Type> (Val)
#   define YY_REINTERPRET_CAST(Type, Val) reinterpret_cast<Type> (Val)
#  else
#   define YY_CAST(Type, Val) ((Type) (Val))
#   define YY_REINTERPRET_CAST(Type, Val) ((Type) (Val))
#  endif
# endif
# ifndef YY_NULLPTR
#  if defined __cplusplus
#   if 201103L <= __cplusplus
#    define YY_NULLPTR nullptr
#   else
#    define YY_NULLPTR 0
#   endif
#  else
#   define YY_NULLPTR ((void*)0)
#  endif
# endif

/* Use api.header.include to #include this header
   instead of duplicating it here.  */
#ifndef YY_YY_LDGRAM_H_INCLUDED
# define YY_YY_LDGRAM_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    INT = 258,                     /* INT  */
    NAME = 259,                    /* NAME  */
    LNAME = 260,                   /* LNAME  */
    PLUSEQ = 261,                  /* PLUSEQ  */
    MINUSEQ = 262,                 /* MINUSEQ  */
    MULTEQ = 263,                  /* MULTEQ  */
    DIVEQ = 264,                   /* DIVEQ  */
    LSHIFTEQ = 265,                /* LSHIFTEQ  */
    RSHIFTEQ = 266,                /* RSHIFTEQ  */
    ANDEQ = 267,                   /* ANDEQ  */
    OREQ = 268,                    /* OREQ  */
    XOREQ = 269,                   /* XOREQ  */
    OROR = 270,                    /* OROR  */
    ANDAND = 271,                  /* ANDAND  */
    EQ = 272,                      /* EQ  */
    NE = 273,                      /* NE  */
    LE = 274,                      /* LE  */
    GE = 275,                      /* GE  */
    LSHIFT = 276,                  /* LSHIFT  */
    RSHIFT = 277,                  /* RSHIFT  */
    UNARY = 278,                   /* UNARY  */
    END = 279,                     /* END  */
    ALIGN_K = 280,                 /* ALIGN_K  */
    BLOCK = 281,                   /* BLOCK  */
    BIND = 282,                    /* BIND  */
    QUAD = 283,                    /* QUAD  */
    SQUAD = 284,                   /* SQUAD  */
    LONG = 285,                    /* LONG  */
    SHORT = 286,                   /* SHORT  */
    BYTE = 287,                    /* BYTE  */
    ASCIZ = 288,                   /* ASCIZ  */
    SECTIONS = 289,                /* SECTIONS  */
    PHDRS = 290,                   /* PHDRS  */
    INSERT_K = 291,                /* INSERT_K  */
    AFTER = 292,                   /* AFTER  */
    BEFORE = 293,                  /* BEFORE  */
    LINKER_VERSION = 294,          /* LINKER_VERSION  */
    DATA_SEGMENT_ALIGN = 295,      /* DATA_SEGMENT_ALIGN  */
    DATA_SEGMENT_RELRO_END = 296,  /* DATA_SEGMENT_RELRO_END  */
    DATA_SEGMENT_END = 297,        /* DATA_SEGMENT_END  */
    SORT_BY_NAME = 298,            /* SORT_BY_NAME  */
    SORT_BY_ALIGNMENT = 299,       /* SORT_BY_ALIGNMENT  */
    SORT_NONE = 300,               /* SORT_NONE  */
    SORT_BY_INIT_PRIORITY = 301,   /* SORT_BY_INIT_PRIORITY  */
    REVERSE = 302,                 /* REVERSE  */
    SIZEOF_HEADERS = 303,          /* SIZEOF_HEADERS  */
    OUTPUT_FORMAT = 304,           /* OUTPUT_FORMAT  */
    FORCE_COMMON_ALLOCATION = 305, /* FORCE_COMMON_ALLOCATION  */
    OUTPUT_ARCH = 306,             /* OUTPUT_ARCH  */
    INHIBIT_COMMON_ALLOCATION = 307, /* INHIBIT_COMMON_ALLOCATION  */
    FORCE_GROUP_ALLOCATION = 308,  /* FORCE_GROUP_ALLOCATION  */
    SEGMENT_START = 309,           /* SEGMENT_START  */
    INCLUDE = 310,                 /* INCLUDE  */
    MEMORY = 311,                  /* MEMORY  */
    REGION_ALIAS = 312,            /* REGION_ALIAS  */
    LD_FEATURE = 313,              /* LD_FEATURE  */
    NOLOAD = 314,                  /* NOLOAD  */
    DSECT = 315,                   /* DSECT  */
    COPY = 316,                    /* COPY  */
    INFO = 317,                    /* INFO  */
    OVERLAY = 318,                 /* OVERLAY  */
    READONLY = 319,                /* READONLY  */
    TYPE = 320,                    /* TYPE  */
    DEFINED = 321,                 /* DEFINED  */
    TARGET_K = 322,                /* TARGET_K  */
    SEARCH_DIR = 323,              /* SEARCH_DIR  */
    MAP = 324,                     /* MAP  */
    ENTRY = 325,                   /* ENTRY  */
    NEXT = 326,                    /* NEXT  */
    SIZEOF = 327,                  /* SIZEOF  */
    ALIGNOF = 328,                 /* ALIGNOF  */
    ADDR = 329,                    /* ADDR  */
    LOADADDR = 330,                /* LOADADDR  */
    MAX_K = 331,                   /* MAX_K  */
    MIN_K = 332,                   /* MIN_K  */
    STARTUP = 333,                 /* STARTUP  */
    HLL = 334,                     /* HLL  */
    SYSLIB = 335,                  /* SYSLIB  */
    FLOAT = 336,                   /* FLOAT  */
    NOFLOAT = 337,                 /* NOFLOAT  */
    NOCROSSREFS = 338,             /* NOCROSSREFS  */
    NOCROSSREFS_TO = 339,          /* NOCROSSREFS_TO  */
    ORIGIN = 340,                  /* ORIGIN  */
    FILL = 341,                    /* FILL  */
    LENGTH = 342,                  /* LENGTH  */
    CREATE_OBJECT_SYMBOLS = 343,   /* CREATE_OBJECT_SYMBOLS  */
    INPUT = 344,                   /* INPUT  */
    GROUP = 345,                   /* GROUP  */
    LIB = 346,                     /* LIB  */
    OUTPUT = 347,                  /* OUTPUT  */
    CONSTRUCTORS = 348,            /* CONSTRUCTORS  */
    ALIGNMOD = 349,                /* ALIGNMOD  */
    AT = 350,                      /* AT  */
    SUBALIGN = 351,                /* SUBALIGN  */
    HIDDEN = 352,                  /* HIDDEN  */
    PROVIDE = 353,                 /* PROVIDE  */
    PROVIDE_HIDDEN = 354,          /* PROVIDE_HIDDEN  */
    AS_NEEDED = 355,               /* AS_NEEDED  */
    CHIP = 356,                    /* CHIP  */
    LIST = 357,                    /* LIST  */
    SECT = 358,                    /* SECT  */
    ABSOLUTE = 359,                /* ABSOLUTE  */
    LOAD = 360,                    /* LOAD  */
    NEWLINE = 361,                 /* NEWLINE  */
    ENDWORD = 362,                 /* ENDWORD  */
    ORDER = 363,                   /* ORDER  */
    NAMEWORD = 364,                /* NAMEWORD  */
    ASSERT_K = 365,                /* ASSERT_K  */
    LOG2CEIL = 366,                /* LOG2CEIL  */
    FORMAT = 367,                  /* FORMAT  */
    PUBLIC = 368,                  /* PUBLIC  */
    DEFSYMEND = 369,               /* DEFSYMEND  */
    BASE = 370,                    /* BASE  */
    ALIAS = 371,                   /* ALIAS  */
    TRUNCATE = 372,                /* TRUNCATE  */
    REL = 373,                     /* REL  */
    INPUT_SCRIPT = 374,            /* INPUT_SCRIPT  */
    INPUT_MRI_SCRIPT = 375,        /* INPUT_MRI_SCRIPT  */
    INPUT_DEFSYM = 376,            /* INPUT_DEFSYM  */
    CASE = 377,                    /* CASE  */
    EXTERN = 378,                  /* EXTERN  */
    START = 379,                   /* START  */
    VERS_TAG = 380,                /* VERS_TAG  */
    VERS_IDENTIFIER = 381,         /* VERS_IDENTIFIER  */
    GLOBAL = 382,                  /* GLOBAL  */
    LOCAL = 383,                   /* LOCAL  */
    VERSIONK = 384,                /* VERSIONK  */
    INPUT_VERSION_SCRIPT = 385,    /* INPUT_VERSION_SCRIPT  */
    INPUT_SECTION_ORDERING_SCRIPT = 386, /* INPUT_SECTION_ORDERING_SCRIPT  */
    KEEP = 387,                    /* KEEP  */
    ONLY_IF_RO = 388,              /* ONLY_IF_RO  */
    ONLY_IF_RW = 389,              /* ONLY_IF_RW  */
    SPECIAL = 390,                 /* SPECIAL  */
    INPUT_SECTION_FLAGS = 391,     /* INPUT_SECTION_FLAGS  */
    ALIGN_WITH_INPUT = 392,        /* ALIGN_WITH_INPUT  */
    EXCLUDE_FILE = 393,            /* EXCLUDE_FILE  */
    CONSTANT = 394,                /* CONSTANT  */
    INPUT_DYNAMIC_LIST = 395       /* INPUT_DYNAMIC_LIST  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif
/* Token kinds.  */
#define YYEMPTY -2
#define YYEOF 0
#define YYerror 256
#define YYUNDEF 257
#define INT 258
#define NAME 259
#define LNAME 260
#define PLUSEQ 261
#define MINUSEQ 262
#define MULTEQ 263
#define DIVEQ 264
#define LSHIFTEQ 265
#define RSHIFTEQ 266
#define ANDEQ 267
#define OREQ 268
#define XOREQ 269
#define OROR 270
#define ANDAND 271
#define EQ 272
#define NE 273
#define LE 274
#define GE 275
#define LSHIFT 276
#define RSHIFT 277
#define UNARY 278
#define END 279
#define ALIGN_K 280
#define BLOCK 281
#define BIND 282
#define QUAD 283
#define SQUAD 284
#define LONG 285
#define SHORT 286
#define BYTE 287
#define ASCIZ 288
#define SECTIONS 289
#define PHDRS 290
#define INSERT_K 291
#define AFTER 292
#define BEFORE 293
#define LINKER_VERSION 294
#define DATA_SEGMENT_ALIGN 295
#define DATA_SEGMENT_RELRO_END 296
#define DATA_SEGMENT_END 297
#define SORT_BY_NAME 298
#define SORT_BY_ALIGNMENT 299
#define SORT_NONE 300
#define SORT_BY_INIT_PRIORITY 301
#define REVERSE 302
#define SIZEOF_HEADERS 303
#define OUTPUT_FORMAT 304
#define FORCE_COMMON_ALLOCATION 305
#define OUTPUT_ARCH 306
#define INHIBIT_COMMON_ALLOCATION 307
#define FORCE_GROUP_ALLOCATION 308
#define SEGMENT_START 309
#define INCLUDE 310
#define MEMORY 311
#define REGION_ALIAS 312
#define LD_FEATURE 313
#define NOLOAD 314
#define DSECT 315
#define COPY 316
#define INFO 317
#define OVERLAY 318
#define READONLY 319
#define TYPE 320
#define DEFINED 321
#define TARGET_K 322
#define SEARCH_DIR 323
#define MAP 324
#define ENTRY 325
#define NEXT 326
#define SIZEOF 327
#define ALIGNOF 328
#define ADDR 329
#define LOADADDR 330
#define MAX_K 331
#define MIN_K 332
#define STARTUP 333
#define HLL 334
#define SYSLIB 335
#define FLOAT 336
#define NOFLOAT 337
#define NOCROSSREFS 338
#define NOCROSSREFS_TO 339
#define ORIGIN 340
#define FILL 341
#define LENGTH 342
#define CREATE_OBJECT_SYMBOLS 343
#define INPUT 344
#define GROUP 345
#define LIB 346
#define OUTPUT 347
#define CONSTRUCTORS 348
#define ALIGNMOD 349
#define AT 350
#define SUBALIGN 351
#define HIDDEN 352
#define PROVIDE 353
#define PROVIDE_HIDDEN 354
#define AS_NEEDED 355
#define CHIP 356
#define LIST 357
#define SECT 358
#define ABSOLUTE 359
#define LOAD 360
#define NEWLINE 361
#define ENDWORD 362
#define ORDER 363
#define NAMEWORD 364
#define ASSERT_K 365
#define LOG2CEIL 366
#define FORMAT 367
#define PUBLIC 368
#define DEFSYMEND 369
#define BASE 370
#define ALIAS 371
#define TRUNCATE 372
#define REL 373
#define INPUT_SCRIPT 374
#define INPUT_MRI_SCRIPT 375
#define INPUT_DEFSYM 376
#define CASE 377
#define EXTERN 378
#define START 379
#define VERS_TAG 380
#define VERS_IDENTIFIER 381
#define GLOBAL 382
#define LOCAL 383
#define VERSIONK 384
#define INPUT_VERSION_SCRIPT 385
#define INPUT_SECTION_ORDERING_SCRIPT 386
#define KEEP 387
#define ONLY_IF_RO 388
#define ONLY_IF_RW 389
#define SPECIAL 390
#define INPUT_SECTION_FLAGS 391
#define ALIGN_WITH_INPUT 392
#define EXCLUDE_FILE 393
#define CONSTANT 394
#define INPUT_DYNAMIC_LIST 395

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 65 "ldgram.y"

  bfd_vma integer;
  struct big_int
    {
      bfd_vma integer;
      char *str;
    } bigint;
  fill_type *fill;
  char *name;
  const char *cname;
  struct wildcard_spec wildcard;
  struct wildcard_list *wildcard_list;
  struct name_list *name_list;
  struct flag_info_list *flag_info_list;
  struct flag_info *flag_info;
  int token;
  union etree_union *etree;
  struct phdr_info
    {
      bool filehdr;
      bool phdrs;
      union etree_union *at;
      union etree_union *flags;
    } phdr;
  struct lang_nocrossref *nocrossref;
  struct lang_output_section_phdr_list *section_phdr;
  struct bfd_elf_version_deps *deflist;
  struct bfd_elf_version_expr *versyms;
  struct bfd_elf_version_tree *versnode;

#line 479 "ldgram.c"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;


int yyparse (void);


#endif /* !YY_YY_LDGRAM_H_INCLUDED  */
/* Symbol kind.  */
enum yysymbol_kind_t
{
  YYSYMBOL_YYEMPTY = -2,
  YYSYMBOL_YYEOF = 0,                      /* "end of file"  */
  YYSYMBOL_YYerror = 1,                    /* error  */
  YYSYMBOL_YYUNDEF = 2,                    /* "invalid token"  */
  YYSYMBOL_INT = 3,                        /* INT  */
  YYSYMBOL_NAME = 4,                       /* NAME  */
  YYSYMBOL_LNAME = 5,                      /* LNAME  */
  YYSYMBOL_PLUSEQ = 6,                     /* PLUSEQ  */
  YYSYMBOL_MINUSEQ = 7,                    /* MINUSEQ  */
  YYSYMBOL_MULTEQ = 8,                     /* MULTEQ  */
  YYSYMBOL_DIVEQ = 9,                      /* DIVEQ  */
  YYSYMBOL_10_ = 10,                       /* '='  */
  YYSYMBOL_LSHIFTEQ = 11,                  /* LSHIFTEQ  */
  YYSYMBOL_RSHIFTEQ = 12,                  /* RSHIFTEQ  */
  YYSYMBOL_ANDEQ = 13,                     /* ANDEQ  */
  YYSYMBOL_OREQ = 14,                      /* OREQ  */
  YYSYMBOL_XOREQ = 15,                     /* XOREQ  */
  YYSYMBOL_16_ = 16,                       /* '?'  */
  YYSYMBOL_17_ = 17,                       /* ':'  */
  YYSYMBOL_OROR = 18,                      /* OROR  */
  YYSYMBOL_ANDAND = 19,                    /* ANDAND  */
  YYSYMBOL_20_ = 20,                       /* '|'  */
  YYSYMBOL_21_ = 21,                       /* '^'  */
  YYSYMBOL_22_ = 22,                       /* '&'  */
  YYSYMBOL_EQ = 23,                        /* EQ  */
  YYSYMBOL_NE = 24,                        /* NE  */
  YYSYMBOL_25_ = 25,                       /* '<'  */
  YYSYMBOL_26_ = 26,                       /* '>'  */
  YYSYMBOL_LE = 27,                        /* LE  */
  YYSYMBOL_GE = 28,                        /* GE  */
  YYSYMBOL_LSHIFT = 29,                    /* LSHIFT  */
  YYSYMBOL_RSHIFT = 30,                    /* RSHIFT  */
  YYSYMBOL_31_ = 31,                       /* '+'  */
  YYSYMBOL_32_ = 32,                       /* '-'  */
  YYSYMBOL_33_ = 33,                       /* '*'  */
  YYSYMBOL_34_ = 34,                       /* '/'  */
  YYSYMBOL_35_ = 35,                       /* '%'  */
  YYSYMBOL_UNARY = 36,                     /* UNARY  */
  YYSYMBOL_END = 37,                       /* END  */
  YYSYMBOL_38_ = 38,                       /* '('  */
  YYSYMBOL_ALIGN_K = 39,                   /* ALIGN_K  */
  YYSYMBOL_BLOCK = 40,                     /* BLOCK  */
  YYSYMBOL_BIND = 41,                      /* BIND  */
  YYSYMBOL_QUAD = 42,                      /* QUAD  */
  YYSYMBOL_SQUAD = 43,                     /* SQUAD  */
  YYSYMBOL_LONG = 44,                      /* LONG  */
  YYSYMBOL_SHORT = 45,                     /* SHORT  */
  YYSYMBOL_BYTE = 46,                      /* BYTE  */
  YYSYMBOL_ASCIZ = 47,                     /* ASCIZ  */
  YYSYMBOL_SECTIONS = 48,                  /* SECTIONS  */
  YYSYMBOL_PHDRS = 49,                     /* PHDRS  */
  YYSYMBOL_INSERT_K = 50,                  /* INSERT_K  */
  YYSYMBOL_AFTER = 51,                     /* AFTER  */
  YYSYMBOL_BEFORE = 52,                    /* BEFORE  */
  YYSYMBOL_LINKER_VERSION = 53,            /* LINKER_VERSION  */
  YYSYMBOL_DATA_SEGMENT_ALIGN = 54,        /* DATA_SEGMENT_ALIGN  */
  YYSYMBOL_DATA_SEGMENT_RELRO_END = 55,    /* DATA_SEGMENT_RELRO_END  */
  YYSYMBOL_DATA_SEGMENT_END = 56,          /* DATA_SEGMENT_END  */
  YYSYMBOL_SORT_BY_NAME = 57,              /* SORT_BY_NAME  */
  YYSYMBOL_SORT_BY_ALIGNMENT = 58,         /* SORT_BY_ALIGNMENT  */
  YYSYMBOL_SORT_NONE = 59,                 /* SORT_NONE  */
  YYSYMBOL_SORT_BY_INIT_PRIORITY = 60,     /* SORT_BY_INIT_PRIORITY  */
  YYSYMBOL_REVERSE = 61,                   /* REVERSE  */
  YYSYMBOL_62_ = 62,                       /* '{'  */
  YYSYMBOL_63_ = 63,                       /* '}'  */
  YYSYMBOL_SIZEOF_HEADERS = 64,            /* SIZEOF_HEADERS  */
  YYSYMBOL_OUTPUT_FORMAT = 65,             /* OUTPUT_FORMAT  */
  YYSYMBOL_FORCE_COMMON_ALLOCATION = 66,   /* FORCE_COMMON_ALLOCATION  */
  YYSYMBOL_OUTPUT_ARCH = 67,               /* OUTPUT_ARCH  */
  YYSYMBOL_INHIBIT_COMMON_ALLOCATION = 68, /* INHIBIT_COMMON_ALLOCATION  */
  YYSYMBOL_FORCE_GROUP_ALLOCATION = 69,    /* FORCE_GROUP_ALLOCATION  */
  YYSYMBOL_SEGMENT_START = 70,             /* SEGMENT_START  */
  YYSYMBOL_INCLUDE = 71,                   /* INCLUDE  */
  YYSYMBOL_MEMORY = 72,                    /* MEMORY  */
  YYSYMBOL_REGION_ALIAS = 73,              /* REGION_ALIAS  */
  YYSYMBOL_LD_FEATURE = 74,                /* LD_FEATURE  */
  YYSYMBOL_NOLOAD = 75,                    /* NOLOAD  */
  YYSYMBOL_DSECT = 76,                     /* DSECT  */
  YYSYMBOL_COPY = 77,                      /* COPY  */
  YYSYMBOL_INFO = 78,                      /* INFO  */
  YYSYMBOL_OVERLAY = 79,                   /* OVERLAY  */
  YYSYMBOL_READONLY = 80,                  /* READONLY  */
  YYSYMBOL_TYPE = 81,                      /* TYPE  */
  YYSYMBOL_DEFINED = 82,                   /* DEFINED  */
  YYSYMBOL_TARGET_K = 83,                  /* TARGET_K  */
  YYSYMBOL_SEARCH_DIR = 84,                /* SEARCH_DIR  */
  YYSYMBOL_MAP = 85,                       /* MAP  */
  YYSYMBOL_ENTRY = 86,                     /* ENTRY  */
  YYSYMBOL_NEXT = 87,                      /* NEXT  */
  YYSYMBOL_SIZEOF = 88,                    /* SIZEOF  */
  YYSYMBOL_ALIGNOF = 89,                   /* ALIGNOF  */
  YYSYMBOL_ADDR = 90,                      /* ADDR  */
  YYSYMBOL_LOADADDR = 91,                  /* LOADADDR  */
  YYSYMBOL_MAX_K = 92,                     /* MAX_K  */
  YYSYMBOL_MIN_K = 93,                     /* MIN_K  */
  YYSYMBOL_STARTUP = 94,                   /* STARTUP  */
  YYSYMBOL_HLL = 95,                       /* HLL  */
  YYSYMBOL_SYSLIB = 96,                    /* SYSLIB  */
  YYSYMBOL_FLOAT = 97,                     /* FLOAT  */
  YYSYMBOL_NOFLOAT = 98,                   /* NOFLOAT  */
  YYSYMBOL_NOCROSSREFS = 99,               /* NOCROSSREFS  */
  YYSYMBOL_NOCROSSREFS_TO = 100,           /* NOCROSSREFS_TO  */
  YYSYMBOL_ORIGIN = 101,                   /* ORIGIN  */
  YYSYMBOL_FILL = 102,                     /* FILL  */
  YYSYMBOL_LENGTH = 103,                   /* LENGTH  */
  YYSYMBOL_CREATE_OBJECT_SYMBOLS = 104,    /* CREATE_OBJECT_SYMBOLS  */
  YYSYMBOL_INPUT = 105,                    /* INPUT  */
  YYSYMBOL_GROUP = 106,                    /* GROUP  */
  YYSYMBOL_LIB = 107,                      /* LIB  */
  YYSYMBOL_OUTPUT = 108,                   /* OUTPUT  */
  YYSYMBOL_CONSTRUCTORS = 109,             /* CONSTRUCTORS  */
  YYSYMBOL_ALIGNMOD = 110,                 /* ALIGNMOD  */
  YYSYMBOL_AT = 111,                       /* AT  */
  YYSYMBOL_SUBALIGN = 112,                 /* SUBALIGN  */
  YYSYMBOL_HIDDEN = 113,                   /* HIDDEN  */
  YYSYMBOL_PROVIDE = 114,                  /* PROVIDE  */
  YYSYMBOL_PROVIDE_HIDDEN = 115,           /* PROVIDE_HIDDEN  */
  YYSYMBOL_AS_NEEDED = 116,                /* AS_NEEDED  */
  YYSYMBOL_CHIP = 117,                     /* CHIP  */
  YYSYMBOL_LIST = 118,                     /* LIST  */
  YYSYMBOL_SECT = 119,                     /* SECT  */
  YYSYMBOL_ABSOLUTE = 120,                 /* ABSOLUTE  */
  YYSYMBOL_LOAD = 121,                     /* LOAD  */
  YYSYMBOL_NEWLINE = 122,                  /* NEWLINE  */
  YYSYMBOL_ENDWORD = 123,                  /* ENDWORD  */
  YYSYMBOL_ORDER = 124,                    /* ORDER  */
  YYSYMBOL_NAMEWORD = 125,                 /* NAMEWORD  */
  YYSYMBOL_ASSERT_K = 126,                 /* ASSERT_K  */
  YYSYMBOL_LOG2CEIL = 127,                 /* LOG2CEIL  */
  YYSYMBOL_FORMAT = 128,                   /* FORMAT  */
  YYSYMBOL_PUBLIC = 129,                   /* PUBLIC  */
  YYSYMBOL_DEFSYMEND = 130,                /* DEFSYMEND  */
  YYSYMBOL_BASE = 131,                     /* BASE  */
  YYSYMBOL_ALIAS = 132,                    /* ALIAS  */
  YYSYMBOL_TRUNCATE = 133,                 /* TRUNCATE  */
  YYSYMBOL_REL = 134,                      /* REL  */
  YYSYMBOL_INPUT_SCRIPT = 135,             /* INPUT_SCRIPT  */
  YYSYMBOL_INPUT_MRI_SCRIPT = 136,         /* INPUT_MRI_SCRIPT  */
  YYSYMBOL_INPUT_DEFSYM = 137,             /* INPUT_DEFSYM  */
  YYSYMBOL_CASE = 138,                     /* CASE  */
  YYSYMBOL_EXTERN = 139,                   /* EXTERN  */
  YYSYMBOL_START = 140,                    /* START  */
  YYSYMBOL_VERS_TAG = 141,                 /* VERS_TAG  */
  YYSYMBOL_VERS_IDENTIFIER = 142,          /* VERS_IDENTIFIER  */
  YYSYMBOL_GLOBAL = 143,                   /* GLOBAL  */
  YYSYMBOL_LOCAL = 144,                    /* LOCAL  */
  YYSYMBOL_VERSIONK = 145,                 /* VERSIONK  */
  YYSYMBOL_INPUT_VERSION_SCRIPT = 146,     /* INPUT_VERSION_SCRIPT  */
  YYSYMBOL_INPUT_SECTION_ORDERING_SCRIPT = 147, /* INPUT_SECTION_ORDERING_SCRIPT  */
  YYSYMBOL_KEEP = 148,                     /* KEEP  */
  YYSYMBOL_ONLY_IF_RO = 149,               /* ONLY_IF_RO  */
  YYSYMBOL_ONLY_IF_RW = 150,               /* ONLY_IF_RW  */
  YYSYMBOL_SPECIAL = 151,                  /* SPECIAL  */
  YYSYMBOL_INPUT_SECTION_FLAGS = 152,      /* INPUT_SECTION_FLAGS  */
  YYSYMBOL_ALIGN_WITH_INPUT = 153,         /* ALIGN_WITH_INPUT  */
  YYSYMBOL_EXCLUDE_FILE = 154,             /* EXCLUDE_FILE  */
  YYSYMBOL_CONSTANT = 155,                 /* CONSTANT  */
  YYSYMBOL_INPUT_DYNAMIC_LIST = 156,       /* INPUT_DYNAMIC_LIST  */
  YYSYMBOL_157_ = 157,                     /* ','  */
  YYSYMBOL_158_ = 158,                     /* ';'  */
  YYSYMBOL_159_ = 159,                     /* ')'  */
  YYSYMBOL_160_ = 160,                     /* '['  */
  YYSYMBOL_161_ = 161,                     /* ']'  */
  YYSYMBOL_162_ = 162,                     /* '!'  */
  YYSYMBOL_163_ = 163,                     /* '~'  */
  YYSYMBOL_YYACCEPT = 164,                 /* $accept  */
  YYSYMBOL_file = 165,                     /* file  */
  YYSYMBOL_filename = 166,                 /* filename  */
  YYSYMBOL_defsym_expr = 167,              /* defsym_expr  */
  YYSYMBOL_168_1 = 168,                    /* $@1  */
  YYSYMBOL_mri_script_file = 169,          /* mri_script_file  */
  YYSYMBOL_170_2 = 170,                    /* $@2  */
  YYSYMBOL_mri_script_lines = 171,         /* mri_script_lines  */
  YYSYMBOL_mri_script_command = 172,       /* mri_script_command  */
  YYSYMBOL_173_3 = 173,                    /* $@3  */
  YYSYMBOL_ordernamelist = 174,            /* ordernamelist  */
  YYSYMBOL_mri_load_name_list = 175,       /* mri_load_name_list  */
  YYSYMBOL_mri_abs_name_list = 176,        /* mri_abs_name_list  */
  YYSYMBOL_casesymlist = 177,              /* casesymlist  */
  YYSYMBOL_extern_name_list = 178,         /* extern_name_list  */
  YYSYMBOL_script_file = 179,              /* script_file  */
  YYSYMBOL_180_4 = 180,                    /* $@4  */
  YYSYMBOL_ifile_list = 181,               /* ifile_list  */
  YYSYMBOL_ifile_p1 = 182,                 /* ifile_p1  */
  YYSYMBOL_183_5 = 183,                    /* $@5  */
  YYSYMBOL_184_6 = 184,                    /* $@6  */
  YYSYMBOL_185_7 = 185,                    /* $@7  */
  YYSYMBOL_186_8 = 186,                    /* $@8  */
  YYSYMBOL_input_list = 187,               /* input_list  */
  YYSYMBOL_188_9 = 188,                    /* $@9  */
  YYSYMBOL_input_list1 = 189,              /* input_list1  */
  YYSYMBOL_190_10 = 190,                   /* @10  */
  YYSYMBOL_191_11 = 191,                   /* @11  */
  YYSYMBOL_192_12 = 192,                   /* @12  */
  YYSYMBOL_sections = 193,                 /* sections  */
  YYSYMBOL_sec_or_group_p1 = 194,          /* sec_or_group_p1  */
  YYSYMBOL_statement_anywhere = 195,       /* statement_anywhere  */
  YYSYMBOL_196_13 = 196,                   /* $@13  */
  YYSYMBOL_wildcard_name = 197,            /* wildcard_name  */
  YYSYMBOL_wildcard_maybe_exclude = 198,   /* wildcard_maybe_exclude  */
  YYSYMBOL_wildcard_maybe_reverse = 199,   /* wildcard_maybe_reverse  */
  YYSYMBOL_filename_spec = 200,            /* filename_spec  */
  YYSYMBOL_section_name_spec = 201,        /* section_name_spec  */
  YYSYMBOL_sect_flag_list = 202,           /* sect_flag_list  */
  YYSYMBOL_sect_flags = 203,               /* sect_flags  */
  YYSYMBOL_exclude_name_list = 204,        /* exclude_name_list  */
  YYSYMBOL_section_name_list = 205,        /* section_name_list  */
  YYSYMBOL_input_section_spec_no_keep = 206, /* input_section_spec_no_keep  */
  YYSYMBOL_input_section_spec = 207,       /* input_section_spec  */
  YYSYMBOL_208_14 = 208,                   /* $@14  */
  YYSYMBOL_statement = 209,                /* statement  */
  YYSYMBOL_210_15 = 210,                   /* $@15  */
  YYSYMBOL_211_16 = 211,                   /* $@16  */
  YYSYMBOL_statement_list = 212,           /* statement_list  */
  YYSYMBOL_statement_list_opt = 213,       /* statement_list_opt  */
  YYSYMBOL_length = 214,                   /* length  */
  YYSYMBOL_fill_exp = 215,                 /* fill_exp  */
  YYSYMBOL_fill_opt = 216,                 /* fill_opt  */
  YYSYMBOL_assign_op = 217,                /* assign_op  */
  YYSYMBOL_separator = 218,                /* separator  */
  YYSYMBOL_assignment = 219,               /* assignment  */
  YYSYMBOL_opt_comma = 220,                /* opt_comma  */
  YYSYMBOL_memory = 221,                   /* memory  */
  YYSYMBOL_memory_spec_list_opt = 222,     /* memory_spec_list_opt  */
  YYSYMBOL_memory_spec_list = 223,         /* memory_spec_list  */
  YYSYMBOL_memory_spec = 224,              /* memory_spec  */
  YYSYMBOL_225_17 = 225,                   /* $@17  */
  YYSYMBOL_226_18 = 226,                   /* $@18  */
  YYSYMBOL_origin_spec = 227,              /* origin_spec  */
  YYSYMBOL_length_spec = 228,              /* length_spec  */
  YYSYMBOL_attributes_opt = 229,           /* attributes_opt  */
  YYSYMBOL_attributes_list = 230,          /* attributes_list  */
  YYSYMBOL_attributes_string = 231,        /* attributes_string  */
  YYSYMBOL_startup = 232,                  /* startup  */
  YYSYMBOL_high_level_library = 233,       /* high_level_library  */
  YYSYMBOL_high_level_library_NAME_list = 234, /* high_level_library_NAME_list  */
  YYSYMBOL_low_level_library = 235,        /* low_level_library  */
  YYSYMBOL_low_level_library_NAME_list = 236, /* low_level_library_NAME_list  */
  YYSYMBOL_floating_point_support = 237,   /* floating_point_support  */
  YYSYMBOL_nocrossref_list = 238,          /* nocrossref_list  */
  YYSYMBOL_paren_script_name = 239,        /* paren_script_name  */
  YYSYMBOL_240_19 = 240,                   /* $@19  */
  YYSYMBOL_mustbe_exp = 241,               /* mustbe_exp  */
  YYSYMBOL_242_20 = 242,                   /* $@20  */
  YYSYMBOL_exp = 243,                      /* exp  */
  YYSYMBOL_244_21 = 244,                   /* $@21  */
  YYSYMBOL_245_22 = 245,                   /* $@22  */
  YYSYMBOL_memspec_at_opt = 246,           /* memspec_at_opt  */
  YYSYMBOL_opt_at = 247,                   /* opt_at  */
  YYSYMBOL_opt_align = 248,                /* opt_align  */
  YYSYMBOL_opt_align_with_input = 249,     /* opt_align_with_input  */
  YYSYMBOL_opt_subalign = 250,             /* opt_subalign  */
  YYSYMBOL_sect_constraint = 251,          /* sect_constraint  */
  YYSYMBOL_section = 252,                  /* section  */
  YYSYMBOL_253_23 = 253,                   /* $@23  */
  YYSYMBOL_254_24 = 254,                   /* $@24  */
  YYSYMBOL_255_25 = 255,                   /* $@25  */
  YYSYMBOL_256_26 = 256,                   /* $@26  */
  YYSYMBOL_257_27 = 257,                   /* $@27  */
  YYSYMBOL_258_28 = 258,                   /* $@28  */
  YYSYMBOL_259_29 = 259,                   /* $@29  */
  YYSYMBOL_260_30 = 260,                   /* $@30  */
  YYSYMBOL_261_31 = 261,                   /* $@31  */
  YYSYMBOL_262_32 = 262,                   /* $@32  */
  YYSYMBOL_263_33 = 263,                   /* $@33  */
  YYSYMBOL_type = 264,                     /* type  */
  YYSYMBOL_atype = 265,                    /* atype  */
  YYSYMBOL_opt_exp_with_type = 266,        /* opt_exp_with_type  */
  YYSYMBOL_opt_exp_without_type = 267,     /* opt_exp_without_type  */
  YYSYMBOL_opt_nocrossrefs = 268,          /* opt_nocrossrefs  */
  YYSYMBOL_memspec_opt = 269,              /* memspec_opt  */
  YYSYMBOL_phdr_opt = 270,                 /* phdr_opt  */
  YYSYMBOL_overlay_section = 271,          /* overlay_section  */
  YYSYMBOL_272_34 = 272,                   /* $@34  */
  YYSYMBOL_273_35 = 273,                   /* $@35  */
  YYSYMBOL_274_36 = 274,                   /* $@36  */
  YYSYMBOL_phdrs = 275,                    /* phdrs  */
  YYSYMBOL_phdr_list = 276,                /* phdr_list  */
  YYSYMBOL_phdr = 277,                     /* phdr  */
  YYSYMBOL_278_37 = 278,                   /* $@37  */
  YYSYMBOL_279_38 = 279,                   /* $@38  */
  YYSYMBOL_phdr_type = 280,                /* phdr_type  */
  YYSYMBOL_phdr_qualifiers = 281,          /* phdr_qualifiers  */
  YYSYMBOL_phdr_val = 282,                 /* phdr_val  */
  YYSYMBOL_dynamic_list_file = 283,        /* dynamic_list_file  */
  YYSYMBOL_284_39 = 284,                   /* $@39  */
  YYSYMBOL_dynamic_list_nodes = 285,       /* dynamic_list_nodes  */
  YYSYMBOL_dynamic_list_node = 286,        /* dynamic_list_node  */
  YYSYMBOL_dynamic_list_tag = 287,         /* dynamic_list_tag  */
  YYSYMBOL_version_script_file = 288,      /* version_script_file  */
  YYSYMBOL_289_40 = 289,                   /* $@40  */
  YYSYMBOL_version = 290,                  /* version  */
  YYSYMBOL_291_41 = 291,                   /* $@41  */
  YYSYMBOL_vers_nodes = 292,               /* vers_nodes  */
  YYSYMBOL_vers_node = 293,                /* vers_node  */
  YYSYMBOL_verdep = 294,                   /* verdep  */
  YYSYMBOL_vers_tag = 295,                 /* vers_tag  */
  YYSYMBOL_vers_defns = 296,               /* vers_defns  */
  YYSYMBOL_297_42 = 297,                   /* @42  */
  YYSYMBOL_298_43 = 298,                   /* @43  */
  YYSYMBOL_opt_semicolon = 299,            /* opt_semicolon  */
  YYSYMBOL_section_ordering_script_file = 300, /* section_ordering_script_file  */
  YYSYMBOL_301_44 = 301,                   /* $@44  */
  YYSYMBOL_section_ordering_list = 302,    /* section_ordering_list  */
  YYSYMBOL_section_order = 303,            /* section_order  */
  YYSYMBOL_304_45 = 304,                   /* $@45  */
  YYSYMBOL_305_46 = 305                    /* $@46  */
};
typedef enum yysymbol_kind_t yysymbol_kind_t;




#ifdef short
# undef short
#endif

/* On compilers that do not define __PTRDIFF_MAX__ etc., make sure
   <limits.h> and (if available) <stdint.h> are included
   so that the code can choose integer types of a good width.  */

#ifndef __PTRDIFF_MAX__
# include <limits.h> /* INFRINGES ON USER NAME SPACE */
# if defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stdint.h> /* INFRINGES ON USER NAME SPACE */
#  define YY_STDINT_H
# endif
#endif

/* Narrow types that promote to a signed type and that can represent a
   signed or unsigned integer of at least N bits.  In tables they can
   save space and decrease cache pressure.  Promoting to a signed type
   helps avoid bugs in integer arithmetic.  */

#ifdef __INT_LEAST8_MAX__
typedef __INT_LEAST8_TYPE__ yytype_int8;
#elif defined YY_STDINT_H
typedef int_least8_t yytype_int8;
#else
typedef signed char yytype_int8;
#endif

#ifdef __INT_LEAST16_MAX__
typedef __INT_LEAST16_TYPE__ yytype_int16;
#elif defined YY_STDINT_H
typedef int_least16_t yytype_int16;
#else
typedef short yytype_int16;
#endif

/* Work around bug in HP-UX 11.23, which defines these macros
   incorrectly for preprocessor constants.  This workaround can likely
   be removed in 2023, as HPE has promised support for HP-UX 11.23
   (aka HP-UX 11i v2) only through the end of 2022; see Table 2 of
   <https://h20195.www2.hpe.com/V2/getpdf.aspx/4AA4-7673ENW.pdf>.  */
#ifdef __hpux
# undef UINT_LEAST8_MAX
# undef UINT_LEAST16_MAX
# define UINT_LEAST8_MAX 255
# define UINT_LEAST16_MAX 65535
#endif

#if defined __UINT_LEAST8_MAX__ && __UINT_LEAST8_MAX__ <= __INT_MAX__
typedef __UINT_LEAST8_TYPE__ yytype_uint8;
#elif (!defined __UINT_LEAST8_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST8_MAX <= INT_MAX)
typedef uint_least8_t yytype_uint8;
#elif !defined __UINT_LEAST8_MAX__ && UCHAR_MAX <= INT_MAX
typedef unsigned char yytype_uint8;
#else
typedef short yytype_uint8;
#endif

#if defined __UINT_LEAST16_MAX__ && __UINT_LEAST16_MAX__ <= __INT_MAX__
typedef __UINT_LEAST16_TYPE__ yytype_uint16;
#elif (!defined __UINT_LEAST16_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST16_MAX <= INT_MAX)
typedef uint_least16_t yytype_uint16;
#elif !defined __UINT_LEAST16_MAX__ && USHRT_MAX <= INT_MAX
typedef unsigned short yytype_uint16;
#else
typedef int yytype_uint16;
#endif

#ifndef YYPTRDIFF_T
# if defined __PTRDIFF_TYPE__ && defined __PTRDIFF_MAX__
#  define YYPTRDIFF_T __PTRDIFF_TYPE__
#  define YYPTRDIFF_MAXIMUM __PTRDIFF_MAX__
# elif defined PTRDIFF_MAX
#  ifndef ptrdiff_t
#   include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  endif
#  define YYPTRDIFF_T ptrdiff_t
#  define YYPTRDIFF_MAXIMUM PTRDIFF_MAX
# else
#  define YYPTRDIFF_T long
#  define YYPTRDIFF_MAXIMUM LONG_MAX
# endif
#endif

#ifndef YYSIZE_T
# ifdef __SIZE_TYPE__
#  define YYSIZE_T __SIZE_TYPE__
# elif defined size_t
#  define YYSIZE_T size_t
# elif defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# else
#  define YYSIZE_T unsigned
# endif
#endif

#define YYSIZE_MAXIMUM                                  \
  YY_CAST (YYPTRDIFF_T,                                 \
           (YYPTRDIFF_MAXIMUM < YY_CAST (YYSIZE_T, -1)  \
            ? YYPTRDIFF_MAXIMUM                         \
            : YY_CAST (YYSIZE_T, -1)))

#define YYSIZEOF(X) YY_CAST (YYPTRDIFF_T, sizeof (X))


/* Stored state numbers (used for stacks). */
typedef yytype_int16 yy_state_t;

/* State numbers in computations.  */
typedef int yy_state_fast_t;

#ifndef YY_
# if defined YYENABLE_NLS && YYENABLE_NLS
#  if ENABLE_NLS
#   include <libintl.h> /* INFRINGES ON USER NAME SPACE */
#   define YY_(Msgid) dgettext ("bison-runtime", Msgid)
#  endif
# endif
# ifndef YY_
#  define YY_(Msgid) Msgid
# endif
#endif


#ifndef YY_ATTRIBUTE_PURE
# if defined __GNUC__ && 2 < __GNUC__ + (96 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_PURE __attribute__ ((__pure__))
# else
#  define YY_ATTRIBUTE_PURE
# endif
#endif

#ifndef YY_ATTRIBUTE_UNUSED
# if defined __GNUC__ && 2 < __GNUC__ + (7 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_UNUSED __attribute__ ((__unused__))
# else
#  define YY_ATTRIBUTE_UNUSED
# endif
#endif

/* Suppress unused-variable warnings by "using" E.  */
#if ! defined lint || defined __GNUC__
# define YY_USE(E) ((void) (E))
#else
# define YY_USE(E) /* empty */
#endif

/* Suppress an incorrect diagnostic about yylval being uninitialized.  */
#if defined __GNUC__ && ! defined __ICC && 406 <= __GNUC__ * 100 + __GNUC_MINOR__
# if __GNUC__ * 100 + __GNUC_MINOR__ < 407
#  define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                           \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")
# else
#  define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                           \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")              \
    _Pragma ("GCC diagnostic ignored \"-Wmaybe-uninitialized\"")
# endif
# define YY_IGNORE_MAYBE_UNINITIALIZED_END      \
    _Pragma ("GCC diagnostic pop")
#else
# define YY_INITIAL_VALUE(Value) Value
#endif
#ifndef YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_END
#endif
#ifndef YY_INITIAL_VALUE
# define YY_INITIAL_VALUE(Value) /* Nothing. */
#endif

#if defined __cplusplus && defined __GNUC__ && ! defined __ICC && 6 <= __GNUC__
# define YY_IGNORE_USELESS_CAST_BEGIN                          \
    _Pragma ("GCC diagnostic push")                            \
    _Pragma ("GCC diagnostic ignored \"-Wuseless-cast\"")
# define YY_IGNORE_USELESS_CAST_END            \
    _Pragma ("GCC diagnostic pop")
#endif
#ifndef YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_END
#endif


#define YY_ASSERT(E) ((void) (0 && (E)))

#if !defined yyoverflow

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   elif defined __BUILTIN_VA_ARG_INCR
#    include <alloca.h> /* INFRINGES ON USER NAME SPACE */
#   elif defined _AIX
#    define YYSTACK_ALLOC __alloca
#   elif defined _MSC_VER
#    include <malloc.h> /* INFRINGES ON USER NAME SPACE */
#    define alloca _alloca
#   else
#    define YYSTACK_ALLOC alloca
#    if ! defined _ALLOCA_H && ! defined EXIT_SUCCESS
#     include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
      /* Use EXIT_SUCCESS as a witness for stdlib.h.  */
#     ifndef EXIT_SUCCESS
#      define EXIT_SUCCESS 0
#     endif
#    endif
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's 'empty if-body' warning.  */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (0)
#  ifndef YYSTACK_ALLOC_MAXIMUM
    /* The OS might guarantee only one guard page at the bottom of the stack,
       and a page size can be as small as 4096 bytes.  So we cannot safely
       invoke alloca (N) if N exceeds 4096.  Use a slightly smaller number
       to allow for a few compiler-allocated temporary stack slots.  */
#   define YYSTACK_ALLOC_MAXIMUM 4032 /* reasonable circa 2006 */
#  endif
# else
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
#  ifndef YYSTACK_ALLOC_MAXIMUM
#   define YYSTACK_ALLOC_MAXIMUM YYSIZE_MAXIMUM
#  endif
#  if (defined __cplusplus && ! defined EXIT_SUCCESS \
       && ! ((defined YYMALLOC || defined malloc) \
             && (defined YYFREE || defined free)))
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   ifndef EXIT_SUCCESS
#    define EXIT_SUCCESS 0
#   endif
#  endif
#  ifndef YYMALLOC
#   define YYMALLOC malloc
#   if ! defined malloc && ! defined EXIT_SUCCESS
void *malloc (YYSIZE_T); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
#  ifndef YYFREE
#   define YYFREE free
#   if ! defined free && ! defined EXIT_SUCCESS
void free (void *); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
# endif
#endif /* !defined yyoverflow */

#if (! defined yyoverflow \
     && (! defined __cplusplus \
         || (defined YYSTYPE_IS_TRIVIAL && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  yy_state_t yyss_alloc;
  YYSTYPE yyvs_alloc;
};

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (YYSIZEOF (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (YYSIZEOF (yy_state_t) + YYSIZEOF (YYSTYPE)) \
      + YYSTACK_GAP_MAXIMUM)

# define YYCOPY_NEEDED 1

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack_alloc, Stack)                           \
    do                                                                  \
      {                                                                 \
        YYPTRDIFF_T yynewbytes;                                         \
        YYCOPY (&yyptr->Stack_alloc, Stack, yysize);                    \
        Stack = &yyptr->Stack_alloc;                                    \
        yynewbytes = yystacksize * YYSIZEOF (*Stack) + YYSTACK_GAP_MAXIMUM; \
        yyptr += yynewbytes / YYSIZEOF (*yyptr);                        \
      }                                                                 \
    while (0)

#endif

#if defined YYCOPY_NEEDED && YYCOPY_NEEDED
/* Copy COUNT objects from SRC to DST.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined __GNUC__ && 1 < __GNUC__
#   define YYCOPY(Dst, Src, Count) \
      __builtin_memcpy (Dst, Src, YY_CAST (YYSIZE_T, (Count)) * sizeof (*(Src)))
#  else
#   define YYCOPY(Dst, Src, Count)              \
      do                                        \
        {                                       \
          YYPTRDIFF_T yyi;                      \
          for (yyi = 0; yyi < (Count); yyi++)   \
            (Dst)[yyi] = (Src)[yyi];            \
        }                                       \
      while (0)
#  endif
# endif
#endif /* !YYCOPY_NEEDED */

/* YYFINAL -- State number of the termination state.  */
#define YYFINAL  20
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   2067

/* YYNTOKENS -- Number of terminals.  */
#define YYNTOKENS  164
/* YYNNTS -- Number of nonterminals.  */
#define YYNNTS  142
/* YYNRULES -- Number of rules.  */
#define YYNRULES  397
/* YYNSTATES -- Number of states.  */
#define YYNSTATES  857

/* YYMAXUTOK -- Last valid token kind.  */
#define YYMAXUTOK   395


/* YYTRANSLATE(TOKEN-NUM) -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex, with out-of-bounds checking.  */
#define YYTRANSLATE(YYX)                                \
  (0 <= (YYX) && (YYX) <= YYMAXUTOK                     \
   ? YY_CAST (yysymbol_kind_t, yytranslate[YYX])        \
   : YYSYMBOL_YYUNDEF)

/* YYTRANSLATE[TOKEN-NUM] -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex.  */
static const yytype_uint8 yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,   162,     2,     2,     2,    35,    22,     2,
      38,   159,    33,    31,   157,    32,     2,    34,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,    17,   158,
      25,    10,    26,    16,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,   160,     2,   161,    21,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,    62,    20,    63,   163,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    11,    12,    13,    14,    15,
      18,    19,    23,    24,    27,    28,    29,    30,    36,    37,
      39,    40,    41,    42,    43,    44,    45,    46,    47,    48,
      49,    50,    51,    52,    53,    54,    55,    56,    57,    58,
      59,    60,    61,    64,    65,    66,    67,    68,    69,    70,
      71,    72,    73,    74,    75,    76,    77,    78,    79,    80,
      81,    82,    83,    84,    85,    86,    87,    88,    89,    90,
      91,    92,    93,    94,    95,    96,    97,    98,    99,   100,
     101,   102,   103,   104,   105,   106,   107,   108,   109,   110,
     111,   112,   113,   114,   115,   116,   117,   118,   119,   120,
     121,   122,   123,   124,   125,   126,   127,   128,   129,   130,
     131,   132,   133,   134,   135,   136,   137,   138,   139,   140,
     141,   142,   143,   144,   145,   146,   147,   148,   149,   150,
     151,   152,   153,   154,   155,   156
};

#if YYDEBUG
/* YYRLINE[YYN] -- Source line where rule number YYN was defined.  */
static const yytype_int16 yyrline[] =
{
       0,   172,   172,   173,   174,   175,   176,   177,   181,   185,
     185,   192,   192,   205,   206,   210,   211,   212,   215,   218,
     219,   220,   222,   224,   226,   228,   230,   232,   234,   236,
     238,   240,   242,   243,   244,   246,   248,   250,   252,   254,
     255,   257,   256,   259,   261,   265,   266,   267,   271,   273,
     277,   279,   284,   285,   286,   290,   292,   294,   299,   299,
     305,   306,   311,   312,   313,   314,   315,   316,   317,   318,
     319,   320,   321,   323,   325,   327,   330,   332,   334,   336,
     338,   340,   342,   341,   346,   345,   349,   352,   351,   354,
     358,   362,   362,   364,   366,   368,   370,   375,   375,   380,
     386,   392,   398,   401,   404,   408,   407,   413,   412,   418,
     417,   425,   429,   430,   431,   435,   437,   438,   438,   444,
     451,   459,   470,   471,   480,   481,   486,   492,   501,   502,
     507,   512,   517,   522,   527,   532,   537,   542,   548,   556,
     574,   595,   608,   617,   628,   637,   648,   657,   666,   670,
     679,   683,   691,   693,   692,   699,   700,   701,   705,   709,
     714,   715,   719,   723,   727,   732,   731,   739,   738,   746,
     747,   750,   752,   756,   758,   760,   762,   764,   769,   776,
     778,   782,   784,   786,   788,   790,   792,   794,   796,   798,
     803,   803,   808,   812,   820,   824,   828,   836,   836,   840,
     843,   843,   846,   847,   852,   851,   857,   856,   862,   869,
     882,   883,   887,   888,   892,   894,   899,   904,   905,   910,
     912,   917,   921,   923,   927,   929,   935,   938,   947,   958,
     958,   962,   962,   968,   970,   972,   974,   976,   978,   981,
     983,   985,   987,   989,   991,   993,   995,   997,   999,  1001,
    1003,  1005,  1007,  1009,  1011,  1013,  1015,  1017,  1019,  1021,
    1023,  1026,  1028,  1030,  1032,  1034,  1036,  1038,  1040,  1042,
    1044,  1046,  1048,  1049,  1048,  1058,  1060,  1062,  1064,  1066,
    1068,  1070,  1072,  1078,  1079,  1083,  1084,  1088,  1089,  1093,
    1094,  1098,  1099,  1103,  1104,  1105,  1106,  1110,  1117,  1126,
    1128,  1109,  1146,  1148,  1150,  1156,  1145,  1171,  1173,  1170,
    1179,  1178,  1186,  1187,  1188,  1189,  1190,  1191,  1192,  1193,
    1197,  1198,  1199,  1203,  1204,  1209,  1210,  1215,  1216,  1221,
    1222,  1227,  1229,  1234,  1237,  1249,  1253,  1260,  1262,  1251,
    1274,  1277,  1279,  1283,  1284,  1283,  1293,  1342,  1345,  1358,
    1367,  1370,  1377,  1377,  1389,  1390,  1394,  1398,  1407,  1407,
    1421,  1421,  1431,  1432,  1436,  1440,  1444,  1451,  1455,  1463,
    1466,  1470,  1474,  1478,  1485,  1489,  1493,  1497,  1502,  1501,
    1515,  1514,  1524,  1528,  1532,  1536,  1540,  1544,  1550,  1552,
    1556,  1556,  1568,  1569,  1570,  1574,  1582,  1573
};
#endif

/** Accessing symbol of state STATE.  */
#define YY_ACCESSING_SYMBOL(State) YY_CAST (yysymbol_kind_t, yystos[State])

#if YYDEBUG || 0
/* The user-facing name of the symbol whose (internal) number is
   YYSYMBOL.  No bounds checking.  */
static const char *yysymbol_name (yysymbol_kind_t yysymbol) YY_ATTRIBUTE_UNUSED;

/* YYTNAME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals.  */
static const char *const yytname[] =
{
  "\"end of file\"", "error", "\"invalid token\"", "INT", "NAME", "LNAME",
  "PLUSEQ", "MINUSEQ", "MULTEQ", "DIVEQ", "'='", "LSHIFTEQ", "RSHIFTEQ",
  "ANDEQ", "OREQ", "XOREQ", "'?'", "':'", "OROR", "ANDAND", "'|'", "'^'",
  "'&'", "EQ", "NE", "'<'", "'>'", "LE", "GE", "LSHIFT", "RSHIFT", "'+'",
  "'-'", "'*'", "'/'", "'%'", "UNARY", "END", "'('", "ALIGN_K", "BLOCK",
  "BIND", "QUAD", "SQUAD", "LONG", "SHORT", "BYTE", "ASCIZ", "SECTIONS",
  "PHDRS", "INSERT_K", "AFTER", "BEFORE", "LINKER_VERSION",
  "DATA_SEGMENT_ALIGN", "DATA_SEGMENT_RELRO_END", "DATA_SEGMENT_END",
  "SORT_BY_NAME", "SORT_BY_ALIGNMENT", "SORT_NONE",
  "SORT_BY_INIT_PRIORITY", "REVERSE", "'{'", "'}'", "SIZEOF_HEADERS",
  "OUTPUT_FORMAT", "FORCE_COMMON_ALLOCATION", "OUTPUT_ARCH",
  "INHIBIT_COMMON_ALLOCATION", "FORCE_GROUP_ALLOCATION", "SEGMENT_START",
  "INCLUDE", "MEMORY", "REGION_ALIAS", "LD_FEATURE", "NOLOAD", "DSECT",
  "COPY", "INFO", "OVERLAY", "READONLY", "TYPE", "DEFINED", "TARGET_K",
  "SEARCH_DIR", "MAP", "ENTRY", "NEXT", "SIZEOF", "ALIGNOF", "ADDR",
  "LOADADDR", "MAX_K", "MIN_K", "STARTUP", "HLL", "SYSLIB", "FLOAT",
  "NOFLOAT", "NOCROSSREFS", "NOCROSSREFS_TO", "ORIGIN", "FILL", "LENGTH",
  "CREATE_OBJECT_SYMBOLS", "INPUT", "GROUP", "LIB", "OUTPUT",
  "CONSTRUCTORS", "ALIGNMOD", "AT", "SUBALIGN", "HIDDEN", "PROVIDE",
  "PROVIDE_HIDDEN", "AS_NEEDED", "CHIP", "LIST", "SECT", "ABSOLUTE",
  "LOAD", "NEWLINE", "ENDWORD", "ORDER", "NAMEWORD", "ASSERT_K",
  "LOG2CEIL", "FORMAT", "PUBLIC", "DEFSYMEND", "BASE", "ALIAS", "TRUNCATE",
  "REL", "INPUT_SCRIPT", "INPUT_MRI_SCRIPT", "INPUT_DEFSYM", "CASE",
  "EXTERN", "START", "VERS_TAG", "VERS_IDENTIFIER", "GLOBAL", "LOCAL",
  "VERSIONK", "INPUT_VERSION_SCRIPT", "INPUT_SECTION_ORDERING_SCRIPT",
  "KEEP", "ONLY_IF_RO", "ONLY_IF_RW", "SPECIAL", "INPUT_SECTION_FLAGS",
  "ALIGN_WITH_INPUT", "EXCLUDE_FILE", "CONSTANT", "INPUT_DYNAMIC_LIST",
  "','", "';'", "')'", "'['", "']'", "'!'", "'~'", "$accept", "file",
  "filename", "defsym_expr", "$@1", "mri_script_file", "$@2",
  "mri_script_lines", "mri_script_command", "$@3", "ordernamelist",
  "mri_load_name_list", "mri_abs_name_list", "casesymlist",
  "extern_name_list", "script_file", "$@4", "ifile_list", "ifile_p1",
  "$@5", "$@6", "$@7", "$@8", "input_list", "$@9", "input_list1", "@10",
  "@11", "@12", "sections", "sec_or_group_p1", "statement_anywhere",
  "$@13", "wildcard_name", "wildcard_maybe_exclude",
  "wildcard_maybe_reverse", "filename_spec", "section_name_spec",
  "sect_flag_list", "sect_flags", "exclude_name_list", "section_name_list",
  "input_section_spec_no_keep", "input_section_spec", "$@14", "statement",
  "$@15", "$@16", "statement_list", "statement_list_opt", "length",
  "fill_exp", "fill_opt", "assign_op", "separator", "assignment",
  "opt_comma", "memory", "memory_spec_list_opt", "memory_spec_list",
  "memory_spec", "$@17", "$@18", "origin_spec", "length_spec",
  "attributes_opt", "attributes_list", "attributes_string", "startup",
  "high_level_library", "high_level_library_NAME_list",
  "low_level_library", "low_level_library_NAME_list",
  "floating_point_support", "nocrossref_list", "paren_script_name", "$@19",
  "mustbe_exp", "$@20", "exp", "$@21", "$@22", "memspec_at_opt", "opt_at",
  "opt_align", "opt_align_with_input", "opt_subalign", "sect_constraint",
  "section", "$@23", "$@24", "$@25", "$@26", "$@27", "$@28", "$@29",
  "$@30", "$@31", "$@32", "$@33", "type", "atype", "opt_exp_with_type",
  "opt_exp_without_type", "opt_nocrossrefs", "memspec_opt", "phdr_opt",
  "overlay_section", "$@34", "$@35", "$@36", "phdrs", "phdr_list", "phdr",
  "$@37", "$@38", "phdr_type", "phdr_qualifiers", "phdr_val",
  "dynamic_list_file", "$@39", "dynamic_list_nodes", "dynamic_list_node",
  "dynamic_list_tag", "version_script_file", "$@40", "version", "$@41",
  "vers_nodes", "vers_node", "verdep", "vers_tag", "vers_defns", "@42",
  "@43", "opt_semicolon", "section_ordering_script_file", "$@44",
  "section_ordering_list", "section_order", "$@45", "$@46", YY_NULLPTR
};

static const char *
yysymbol_name (yysymbol_kind_t yysymbol)
{
  return yytname[yysymbol];
}
#endif

#define YYPACT_NINF (-794)

#define yypact_value_is_default(Yyn) \
  ((Yyn) == YYPACT_NINF)

#define YYTABLE_NINF (-361)

#define yytable_value_is_error(Yyn) \
  0

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
static const yytype_int16 yypact[] =
{
     -73,  -794,  -794,  -794,  -794,  -794,  -794,    31,  -794,  -794,
    -794,  -794,  -794,   247,  -794,   -24,  -794,  -794,  -794,    -3,
    -794,  1016,  1828,   788,    11,    37,    55,  -794,   120,    43,
     -24,  -794,    28,   134,    -3,  -794,    74,    78,    71,    95,
    -794,   229,  -794,  -794,   108,   212,   250,   262,   263,   269,
     271,   274,   292,   296,   310,  -794,  -794,   311,   312,   313,
    -794,  -794,   326,  -794,   327,  -794,  -794,  -794,  -794,  -117,
    -794,  -794,  -794,  -794,  -794,  -794,  -794,   227,  -794,   369,
     108,   370,   830,  -794,   371,   372,   374,  -794,  -794,   375,
     380,   385,   830,   386,   395,   397,   398,   401,   277,  -794,
    -794,  -794,  -794,  -794,  -794,  -794,  -794,  -794,  -794,  -794,
     402,   407,   408,  -794,   409,  -794,   399,   400,   355,   261,
     120,  -794,   928,  -794,  -794,  -794,  -794,   358,   267,  -794,
    -794,  -794,   422,   426,   427,   428,  -794,  -794,    19,   431,
     440,   441,   108,   108,   442,   108,    24,  -794,   443,   443,
    -794,   414,   415,   108,   416,  -794,  -794,  -794,  -794,   387,
      14,  -794,    87,  -794,  -794,   830,   830,   830,   417,   418,
     432,   433,   434,  -794,  -794,   438,   439,  -794,  -794,  -794,
    -794,   446,   447,  -794,  -794,   448,   449,   450,   453,   830,
     830,  1626,   419,  -794,   321,  -794,   322,    16,  -794,  -794,
     574,  2018,   323,  -794,  -794,   324,  -794,    82,  -794,  -794,
    -794,   830,  -794,   483,   484,   485,   437,   134,   134,   338,
     238,   451,  -794,   342,   238,   494,    44,  -794,  -794,   -20,
     343,  -794,  -794,   108,   455,   -11,  -794,   347,   346,   354,
     357,   360,   364,   373,  -794,  -794,     5,   123,    84,   376,
     377,   379,    32,  -794,  -794,   381,   830,   398,   -24,   830,
     830,  -794,   830,   830,  -794,  -794,  1221,   830,   830,   830,
     830,   830,   490,   525,   830,  -794,   492,  -794,  -794,  -794,
     830,   830,  -794,  -794,   830,   830,   830,   527,  -794,  -794,
     830,   830,   830,   830,   830,   830,   830,   830,   830,   830,
     830,   830,   830,   830,   830,   830,   830,   830,   830,   830,
     830,   830,  2018,   529,   530,  -794,   537,   830,   830,  2018,
     141,   538,  -794,   543,  2018,  -794,  -794,  -794,  -794,   390,
     391,  -794,  -794,   546,  -794,  -794,  -794,  -116,   489,  -794,
     788,  -794,   108,  -794,  -794,  -794,  -794,  -794,  -794,  -794,
     548,  -794,  -794,  1099,   515,  -794,  -794,  -794,    19,   550,
    -794,  -794,  -794,  -794,  -794,  -794,  -794,   108,  -794,   108,
     443,  -794,  -794,  -794,  -794,  -794,  -794,   518,    50,   403,
     404,  -794,  1647,    17,   -28,  2018,  2018,  1853,  2018,  2018,
    -794,   978,  1242,  1668,  1688,  1262,   554,   405,  1282,   555,
    1708,  1728,  1302,  1766,  1322,   410,  1978,  1028,  1746,  1847,
    2032,  1902,  1201,  1201,   293,   293,   293,   293,    47,    47,
     237,   237,  -794,  -794,  -794,  2018,  2018,  2018,  -794,  -794,
    -794,  2018,  2018,  -794,  -794,  -794,  -794,   413,   420,   424,
     134,   244,   238,   498,  -794,  -794,  -102,   920,   684,  -794,
     789,   684,   830,   429,  -794,     8,   544,    19,  -794,   430,
    -794,  -794,  -794,  -794,  -794,  -794,   528,    39,  -794,  -794,
     563,  -794,  -794,  -794,   830,  -794,  -794,   830,   830,  -794,
    -794,  -794,  -794,   435,   830,   830,  -794,   564,  -794,  -794,
     830,  -794,  -794,  -794,   412,   558,  -794,  -794,  -794,   454,
    -794,  -794,  -794,  -794,  -794,   581,  -794,   549,   552,   559,
     108,   560,  -794,  -794,  -794,   561,   566,   572,  -794,    92,
    -794,  -794,  -794,   573,    41,  -794,  -794,  -794,   920,   533,
     578,  -117,   265,   579,  1882,   571,   481,  -794,  -794,  1998,
     503,  -794,  2018,    23,   614,  -794,   617,    18,  -794,   522,
     587,  -794,    32,  -794,  -794,  -794,   588,   466,  1342,  1363,
    1384,   470,  -794,  1404,  1424,   472,  2018,   238,   569,   134,
     134,  -794,   254,    54,   112,  -794,  -794,   595,  -794,   630,
     631,  -794,   599,   601,   602,   603,   604,  -794,  -794,   -70,
      92,   605,   607,    92,   608,  -794,  -794,  -794,  -794,  -794,
    -794,  -794,  -794,  -794,   609,   638,  -794,   491,   830,   362,
     634,  -794,   615,   613,   411,  -794,  -794,   481,   592,   619,
     620,  -794,   496,  -794,  -794,  -794,   650,   511,  -794,    90,
      32,  -794,  -794,  -794,  -794,  -794,   830,  -794,  -794,  -794,
    -794,   512,   412,   633,   510,   513,   514,   636,   517,   920,
     519,  -794,   830,    42,  -794,   -12,  -794,    25,   241,   253,
      54,    54,   256,  -794,    92,   126,    54,   -32,    92,   511,
     520,   610,   830,  -794,  1444,  -794,   830,   642,   531,  -794,
     570,  -794,   830,    23,   830,   532,  -794,  -794,   582,  -794,
     122,    32,  1464,   238,   623,   100,  -794,  -794,  -794,   100,
    -794,   656,  -794,  1787,   536,   539,   688,  -794,   631,  -794,
     658,   659,   540,   664,   665,   545,   547,   551,   669,   670,
    -794,  -794,  -794,   132,  -794,  -794,   699,  2018,   268,  1484,
     830,  -794,   570,   673,  -794,   655,  1505,  -794,  1526,  -794,
    -794,   702,  -794,  -794,   127,  -794,  -794,   562,  -794,   709,
    -794,  -794,  -794,    54,    54,  -794,    54,    54,  -794,  -794,
    -794,   100,   100,  -794,   830,   676,   700,  -794,  1546,   144,
     830,   657,  -794,  -794,    23,  -794,  -794,   568,   576,   583,
     584,   585,   586,   590,   591,  1566,   830,  -794,  -794,  -794,
    -794,  -794,  -794,  1586,  -794,  -794,  -794,  -794,  -117,   593,
     594,   596,   597,   598,   600,  -794,  1606,   666,  -794,  -794,
    -794,  -794,  -794,  -794,  -794,  -794,  -794,   682,   920,    57,
     713,   683,  -794,   706,  -794,  -794,   671,   743,   640,   706,
     920,  -794,   732,  -794,   640,   697,   758,    60,  -794,  -794,
    -794,  -794,   759,  -794,    60,  -794,  -794,  -794,   511,  -794,
      60,  -794,   511,  -794,  -794,   511,  -794
};

/* YYDEFACT[STATE-NUM] -- Default reduction number in state STATE-NUM.
   Performed when YYTABLE does not specify something else to do.  Zero
   means the default is an error.  */
static const yytype_int16 yydefact[] =
{
       0,    58,    11,     9,   358,   390,   352,     0,     2,    61,
       3,    14,     7,     0,     4,     0,     5,   394,     6,     0,
       1,    59,    12,     0,     0,     0,     0,    10,   369,     0,
     359,   362,   391,     0,   353,   354,     0,     0,     0,     0,
      78,     0,    80,    79,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,   224,   225,     0,     0,     0,
      82,    84,     0,   117,     0,    71,    60,    63,    69,     0,
      62,    65,    66,    67,    68,    64,    70,     0,    17,     0,
       0,     0,     0,    18,     0,     0,     0,    20,    47,     0,
       0,     0,     0,     0,     0,    52,     0,     0,     0,   181,
     182,   183,   184,   231,   185,   186,   187,   188,   189,   231,
       0,     0,     0,   375,   386,   374,   382,   384,     0,     0,
     369,   363,     0,   393,   392,   382,   384,     0,     0,   355,
     114,   341,     0,     0,     0,     0,     8,    87,   201,     0,
       0,     0,     0,     0,     0,     0,     0,   223,   226,   226,
      97,     0,     0,     0,     0,    91,   191,   190,   116,     0,
       0,    41,     0,   259,   276,     0,     0,     0,     0,     0,
       0,     0,     0,   260,   272,     0,     0,   229,   229,   229,
     229,     0,     0,   229,   229,     0,     0,     0,     0,     0,
       0,    15,     0,    50,    32,    48,    33,    19,    34,    24,
       0,    37,     0,    38,    53,    39,    55,    40,    43,    13,
     192,     0,   193,     0,     0,     0,     0,     0,     0,     0,
     370,     0,   395,     0,   357,     0,     0,    93,    94,     0,
       0,    61,   204,     0,     0,   198,   203,     0,     0,     0,
       0,     0,     0,     0,   218,   220,   198,   198,   226,     0,
       0,     0,     0,    97,    97,     0,     0,     0,     0,     0,
       0,    14,     0,     0,   237,   233,     0,     0,     0,     0,
       0,     0,     0,     0,     0,   262,     0,   261,   263,   264,
       0,     0,   280,   281,     0,     0,     0,     0,   236,   238,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,    26,     0,     0,    46,     0,     0,     0,    23,
       0,     0,    56,     0,   232,   231,   231,   231,   380,     0,
       0,   364,   377,   387,   376,   383,   385,     0,     0,   356,
     297,   111,     0,   302,   307,   113,   112,   343,   340,   342,
       0,    75,    77,   360,   210,   206,   199,   197,     0,     0,
      96,    72,    73,    86,   115,   216,   217,     0,   221,     0,
     226,   227,    89,    90,    81,    99,   102,     0,    98,     0,
       0,    74,     0,     0,     0,    28,    29,    44,    30,    31,
     234,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,   257,   256,   254,
     253,   252,   246,   247,   250,   251,   248,   249,   244,   245,
     242,   243,   239,   240,   241,    16,    27,    25,    51,    49,
      45,    21,    22,    36,    35,    54,    57,     0,     0,     0,
       0,   371,   372,     0,   367,   365,     0,   171,   321,   310,
       0,   321,     0,     0,    88,     0,     0,   201,   202,     0,
     219,   222,   228,   105,   101,   104,     0,     0,    83,    85,
       0,    92,   361,    42,     0,   267,   275,     0,     0,   271,
     273,   258,   235,     0,     0,     0,   266,     0,   282,   265,
       0,   194,   195,   196,   388,   385,   378,   368,   366,   146,
     173,   174,   175,   176,   177,     0,   164,     0,     0,     0,
       0,     0,   157,   158,   165,     0,     0,     0,   155,     0,
     120,   122,   124,     0,     0,   152,   160,   170,   172,     0,
       0,     0,     0,     0,   321,     0,   286,   114,   328,     0,
     329,   308,   346,   347,     0,   214,     0,     0,   212,     0,
       0,    95,     0,   109,   100,   103,     0,     0,     0,     0,
       0,     0,   230,     0,     0,     0,   255,   389,     0,     0,
       0,   162,     0,     0,     0,   167,   231,     0,   153,     0,
       0,   119,     0,     0,     0,     0,     0,   128,   145,   198,
       0,   147,     0,     0,     0,   169,   396,   231,   156,   312,
     313,   314,   315,   316,   318,     0,   322,     0,     0,     0,
       0,   324,     0,   288,     0,   327,   330,   286,     0,   350,
       0,   344,     0,   215,   211,   213,     0,   198,   207,     0,
       0,   107,   118,   268,   269,   270,     0,   277,   278,   279,
     381,     0,   388,     0,     0,     0,     0,     0,     0,   171,
       0,   178,     0,     0,   139,     0,   143,     0,     0,     0,
       0,     0,     0,   148,     0,   198,     0,   198,     0,   198,
       0,     0,     0,   320,     0,   323,     0,     0,   290,   311,
     292,   114,     0,   347,     0,     0,    76,   231,     0,   106,
       0,     0,     0,   373,     0,     0,   159,   125,   126,     0,
     123,     0,   163,     0,   119,     0,     0,   141,     0,   142,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
     144,   150,   149,   198,   397,   161,     0,   319,   321,     0,
       0,   289,   292,     0,   303,     0,     0,   348,     0,   345,
     208,     0,   205,   110,     0,   274,   379,     0,   168,     0,
     154,   140,   121,     0,     0,   129,     0,     0,   130,   131,
     136,     0,     0,   151,     0,     0,     0,   285,     0,   296,
       0,     0,   309,   351,   347,   231,   108,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,   325,   287,   293,
     294,   295,   298,     0,   304,   349,   209,   127,     0,     0,
       0,     0,     0,     0,     0,   317,     0,     0,   291,   335,
     166,   133,   132,   134,   135,   137,   138,   321,   171,     0,
       0,     0,   336,   332,   326,   299,     0,     0,   284,   332,
     171,   331,     0,   333,   284,     0,     0,   180,   333,   337,
     283,   231,     0,   305,   180,   333,   179,   334,   198,   300,
     180,   306,   198,   338,   301,   198,   339
};

/* YYPGOTO[NTERM-NUM].  */
static const yytype_int16 yypgoto[] =
{
    -794,  -794,   -77,  -794,  -794,  -794,  -794,   504,  -794,  -794,
    -794,  -794,  -794,  -794,   507,  -794,  -794,   553,  -794,  -794,
    -794,  -794,  -794,    64,  -794,  -291,  -794,  -794,  -794,  -794,
    -431,   -15,  -794,  -547,  -527,  -501,   243,   114,  -794,  -794,
    -794,  -540,   129,  -794,  -794,   251,  -794,  -794,  -794,  -633,
    -794,   -61,  -793,  -794,  -523,   -13,  -233,  -794,   329,  -794,
     425,  -794,  -794,  -794,  -794,  -794,  -794,   242,  -794,  -794,
    -794,  -794,  -794,  -794,  -130,   153,  -794,   -94,  -794,   -81,
    -794,  -794,   -46,   173,  -794,  -794,    59,  -794,  -794,  -794,
    -794,  -794,  -794,  -794,  -794,  -794,  -794,  -794,  -794,  -794,
    -794,  -530,   356,  -794,  -794,   -21,  -778,  -794,  -794,  -794,
    -794,  -794,  -794,  -794,  -794,  -794,  -794,  -653,  -794,  -794,
    -794,  -794,   775,  -794,  -794,  -794,  -794,  -794,   556,   -25,
    -794,   692,   -26,  -794,  -794,   171,  -794,  -794,  -794,  -794,
    -794,  -794
};

/* YYDEFGOTO[NTERM-NUM].  */
static const yytype_int16 yydefgoto[] =
{
       0,     7,   137,    12,    13,    10,    11,    22,    98,   261,
     197,   196,   194,   205,   207,     8,     9,    21,    66,   151,
     152,   231,   257,   251,   252,   378,   552,   691,   630,    67,
     225,   345,   154,   520,   521,   522,   523,   588,   655,   524,
     657,   589,   525,   526,   653,   527,   577,   649,   528,   529,
     530,   650,   843,   109,   158,    69,   664,    70,   234,   235,
     236,   354,   457,   627,   742,   456,   547,   548,    71,    72,
     246,    73,   247,    74,   249,   275,   276,   651,   211,   266,
     272,   561,   833,   613,   678,   732,   734,   792,   346,   448,
     807,   829,   852,   450,   771,   809,   848,   451,   618,   537,
     607,   535,   536,   540,   617,   828,   837,   819,   826,   845,
     855,    75,   226,   349,   452,   685,   543,   621,   683,    18,
      19,    34,    35,   127,    14,    15,    76,    77,    30,    31,
     446,   118,   119,   570,   440,   568,    16,    17,    32,   124,
     338,   669
};

/* YYTABLE[YYPACT[STATE-NUM]] -- What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule whose
   number is the opposite.  If YYTABLE_NINF, syntax error.  */
static const yytype_int16 yytable[] =
{
      27,   191,   358,   161,   610,   121,    68,   128,   598,   210,
     706,   201,   545,   367,   369,   212,   701,   123,   587,   250,
     315,   322,   545,   232,   259,   444,  -200,   619,   136,   581,
     737,    20,   122,   656,    28,   472,   375,   376,    28,   497,
     156,   157,   445,   554,   555,   591,   704,   648,   347,   110,
     665,   849,  -200,   667,   464,   465,   498,   853,   581,    33,
     844,   822,     1,     2,     3,   240,   241,   850,   243,   245,
     841,   645,   646,     4,     5,   111,   255,   842,   304,   305,
     306,   307,   308,     6,   264,   265,   322,   357,   248,   587,
     233,   663,   587,   112,   464,   465,   581,   262,   592,   592,
     508,   508,   509,   509,   581,   120,   614,   348,   288,   289,
     709,   312,   136,    29,    51,   643,   581,    29,   371,   319,
     823,   795,   132,   133,   113,   357,   464,   465,   723,   722,
     324,   464,   465,   134,   620,   648,   130,   350,   113,   351,
     131,    24,    25,    26,   433,   434,   357,   707,   377,   582,
     583,   584,   585,   586,    63,   556,   355,   712,   715,   716,
     717,   752,   357,   587,   366,   645,   466,   587,   648,   647,
     546,   260,   747,   316,   323,   382,   471,   624,   385,   386,
     546,   388,   389,   244,   708,   821,   391,   392,   393,   394,
     395,   329,   330,   398,   516,   517,   517,   835,   766,   400,
     401,   593,   519,   402,   403,   404,   466,   467,   517,   406,
     407,   408,   409,   410,   411,   412,   413,   414,   415,   416,
     417,   418,   419,   420,   421,   422,   423,   424,   425,   426,
     427,   437,   438,   439,   783,   784,   431,   432,   466,   323,
     462,   370,   332,   466,   263,   581,   517,   467,   332,   689,
     735,    23,   779,   780,   517,   781,   782,   581,   581,   114,
     581,   629,   115,   116,   117,   449,   517,   135,   163,   164,
     306,   307,   308,   114,   138,   810,   115,   125,   126,   467,
     357,   743,   368,   357,   467,   721,   776,   820,   139,   357,
     460,   763,   461,   789,   790,   791,   165,   166,   710,   711,
     140,   141,   643,   167,   168,   169,   609,   142,   765,   143,
     713,   714,   144,   718,   643,   643,   719,   379,   380,   170,
     171,   172,   302,   303,   304,   305,   306,   307,   308,   173,
     145,   277,   278,   279,   146,   174,   282,   283,    68,   690,
     599,   600,   601,   602,   603,   604,   605,   175,   147,   148,
     149,   150,   176,   177,   178,   179,   180,   181,   182,   121,
      24,    25,    26,   644,   153,   155,   183,   534,   184,   539,
     534,   542,   159,   160,   162,   192,   193,   333,   195,   198,
     334,   335,   336,   333,   199,   185,   334,   335,   495,   200,
     202,   186,   187,   558,   688,   517,   559,   560,   203,   209,
     744,   204,   206,   563,   564,   208,   213,   517,   517,   566,
     517,   214,   215,   216,   494,   340,   217,   218,   219,   220,
     188,   223,   163,   164,   606,   224,   227,   189,   190,   310,
     228,   229,   230,   575,   531,   237,   724,   599,   600,   601,
     602,   603,   604,   605,   238,   239,   242,   248,   679,   258,
     165,   166,   253,   254,   256,   267,   268,   167,   168,   169,
      99,   100,   101,   102,   103,   104,   105,   106,   107,   108,
     269,   270,   271,   170,   171,   172,   273,   274,   313,   314,
     320,   321,   342,   173,   280,   281,   284,   285,   286,   174,
     343,   287,  -119,   325,   326,   327,   331,    51,   340,   328,
     339,   175,   352,   670,   359,   360,   176,   177,   178,   179,
     180,   181,   182,   361,   337,   531,   362,   344,   356,   363,
     183,   606,   184,   364,    24,    25,    26,   674,   396,   397,
     399,   405,   365,   428,   429,   372,   373,    63,   374,   185,
     381,   430,   435,   641,   642,   186,   187,   436,   441,   442,
     443,   447,   453,   455,   459,   692,   463,   341,   480,   483,
     496,   549,   468,   469,   481,   342,   553,   557,   565,   489,
     567,   703,   491,   343,   188,   569,   311,   163,   164,   492,
      51,   189,   190,   493,   317,   571,   544,   572,   611,   551,
     573,   727,   612,   740,   562,   729,   596,   574,   576,   578,
     344,   736,   616,   738,   579,   165,   166,    24,    25,    26,
     580,   590,   167,   168,   169,   851,   597,   608,   622,   854,
      63,   623,   856,   626,   628,   632,   631,   636,   170,   171,
     172,   639,   640,   652,   654,   581,   531,   658,   173,   659,
     660,   661,   662,  -119,   174,   666,   668,   671,   672,   768,
     673,   675,   677,   676,   681,   686,   175,   682,   684,   340,
     687,   176,   177,   178,   179,   180,   181,   182,   357,   696,
     693,   695,   697,   698,   699,   183,   700,   184,   702,   725,
     730,   796,   733,   785,   731,   741,   746,   163,   164,   793,
     739,   726,   751,   748,   185,  -146,   753,   754,   750,   755,
     186,   187,   756,   757,   758,   806,   759,   761,   762,   764,
     760,   770,   775,   778,   786,   165,   166,   787,   772,   794,
     609,   777,   532,   168,   169,   533,   342,   797,   818,   188,
     824,   318,   827,   830,   343,   798,   189,   190,   170,   171,
     172,    51,   799,   800,   801,   802,   825,   831,   173,   803,
     804,   832,   811,   812,   174,   813,   814,   815,   836,   816,
     839,   344,   840,   847,   383,   387,   175,   594,    24,    25,
      26,   176,   177,   178,   179,   180,   181,   182,   720,   595,
     846,    63,   705,   458,   353,   183,   550,   184,   838,   625,
     680,   769,   163,   164,    99,   100,   101,   102,   103,   104,
     105,   106,   107,   108,   185,   531,   538,   541,   834,   129,
     186,   187,   221,   694,   384,     0,     0,   531,     0,     0,
     165,   166,     0,     0,     0,     0,     0,   167,   168,   169,
       0,     0,     0,   163,   164,     0,     0,     0,     0,   188,
       0,     0,     0,   170,   171,   172,   189,   190,     0,     0,
       0,     0,     0,   173,     0,     0,     0,     0,     0,   174,
       0,   165,   166,     0,     0,     0,     0,     0,   167,   168,
     169,   175,     0,     0,     0,     0,   176,   177,   178,   179,
     180,   181,   182,     0,   170,   171,   172,     0,     0,     0,
     183,     0,   184,     0,   173,     0,     0,     0,     0,     0,
     174,     0,     0,     0,     0,     0,     0,     0,     0,   185,
       0,     0,   175,     0,     0,   186,   187,   176,   177,   178,
     179,   180,   181,   182,   499,     0,     0,     0,     0,     0,
       0,   183,     0,   184,    99,   100,   101,   102,   103,   104,
     105,   106,   107,   108,   188,   222,     0,     0,     0,     0,
     185,   189,   190,     0,     0,     0,   186,   187,     0,     0,
       0,     0,   500,   501,   502,   503,   504,   505,     0,     0,
       0,     0,     0,   506,     0,     0,     0,   507,     0,   508,
       0,   509,     0,     0,     0,   188,     0,     0,     0,     0,
       0,   510,   189,   190,   290,     0,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,     0,     0,     0,     0,     0,     0,
      23,     0,   511,     0,   512,     0,     0,     0,     0,   513,
       0,     0,     0,    24,    25,    26,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,   514,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,    36,    37,    38,     0,   515,     0,
       0,     0,   516,     0,   517,     0,     0,     0,   518,     0,
     519,    39,    40,    41,    42,    43,     0,    44,    45,    46,
      47,     0,     0,     0,     0,     0,     0,     0,     0,    48,
      49,    50,    51,    23,     0,     0,     0,     0,     0,     0,
      52,    53,    54,    55,    56,    57,    58,     0,     0,     0,
       0,    59,    60,    61,    62,     0,     0,     0,     0,    24,
      25,    26,     0,     0,     0,   474,   454,   475,     0,     0,
       0,     0,    63,     0,     0,     0,     0,    36,    37,    38,
       0,     0,     0,     0,     0,    64,     0,     0,     0,     0,
       0,  -360,     0,     0,    39,    40,    41,    42,    43,     0,
      44,    45,    46,    47,    65,     0,     0,     0,     0,     0,
       0,     0,    48,    49,    50,    51,     0,     0,     0,     0,
       0,     0,     0,    52,    53,    54,    55,    56,    57,    58,
       0,     0,     0,     0,    59,    60,    61,    62,     0,     0,
       0,     0,    24,    25,    26,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,    63,   298,   299,   300,   301,
     302,   303,   304,   305,   306,   307,   308,   290,    64,   291,
     292,   293,   294,   295,   296,   297,   298,   299,   300,   301,
     302,   303,   304,   305,   306,   307,   308,    65,   290,     0,
     291,   292,   293,   294,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,   290,     0,
     291,   292,   293,   294,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,   290,     0,
     291,   292,   293,   294,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,   290,     0,
     291,   292,   293,   294,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,   290,     0,
     291,   292,   293,   294,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,   290,     0,
     291,   292,   293,   294,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,     0,   290,
     390,   291,   292,   293,   294,   295,   296,   297,   298,   299,
     300,   301,   302,   303,   304,   305,   306,   307,   308,     0,
     290,   476,   291,   292,   293,   294,   295,   296,   297,   298,
     299,   300,   301,   302,   303,   304,   305,   306,   307,   308,
     290,   479,   291,   292,   293,   294,   295,   296,   297,   298,
     299,   300,   301,   302,   303,   304,   305,   306,   307,   308,
     290,   482,   291,   292,   293,   294,   295,   296,   297,   298,
     299,   300,   301,   302,   303,   304,   305,   306,   307,   308,
     290,   486,   291,   292,   293,   294,   295,   296,   297,   298,
     299,   300,   301,   302,   303,   304,   305,   306,   307,   308,
     290,   488,   291,   292,   293,   294,   295,   296,   297,   298,
     299,   300,   301,   302,   303,   304,   305,   306,   307,   308,
     290,   633,   291,   292,   293,   294,   295,   296,   297,   298,
     299,   300,   301,   302,   303,   304,   305,   306,   307,   308,
       0,   290,   634,   291,   292,   293,   294,   295,   296,   297,
     298,   299,   300,   301,   302,   303,   304,   305,   306,   307,
     308,     0,   290,   635,   291,   292,   293,   294,   295,   296,
     297,   298,   299,   300,   301,   302,   303,   304,   305,   306,
     307,   308,   290,   637,   291,   292,   293,   294,   295,   296,
     297,   298,   299,   300,   301,   302,   303,   304,   305,   306,
     307,   308,   290,   638,   291,   292,   293,   294,   295,   296,
     297,   298,   299,   300,   301,   302,   303,   304,   305,   306,
     307,   308,   290,   728,   291,   292,   293,   294,   295,   296,
     297,   298,   299,   300,   301,   302,   303,   304,   305,   306,
     307,   308,   290,   745,   291,   292,   293,   294,   295,   296,
     297,   298,   299,   300,   301,   302,   303,   304,   305,   306,
     307,   308,   290,   767,   291,   292,   293,   294,   295,   296,
     297,   298,   299,   300,   301,   302,   303,   304,   305,   306,
     307,   308,     0,   290,   773,   291,   292,   293,   294,   295,
     296,   297,   298,   299,   300,   301,   302,   303,   304,   305,
     306,   307,   308,     0,   290,   774,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,   290,   788,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,   290,   805,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,   290,   808,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,     0,   817,   293,   294,   295,   296,
     297,   298,   299,   300,   301,   302,   303,   304,   305,   306,
     307,   308,   290,   309,   291,   292,   293,   294,   295,   296,
     297,   298,   299,   300,   301,   302,   303,   304,   305,   306,
     307,   308,     0,   290,   470,   291,   292,   293,   294,   295,
     296,   297,   298,   299,   300,   301,   302,   303,   304,   305,
     306,   307,   308,     0,     0,   477,     0,     0,     0,     0,
       0,     0,    78,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,   478,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,    78,     0,     0,
       0,     0,     0,     0,     0,   484,     0,    79,   294,   295,
     296,   297,   298,   299,   300,   301,   302,   303,   304,   305,
     306,   307,   308,     0,     0,   485,     0,     0,     0,     0,
     473,     0,    79,     0,     0,     0,     0,     0,   290,    80,
     291,   292,   293,   294,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,     0,     0,
     609,     0,     0,   487,    80,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,    81,     0,
       0,     0,     0,     0,   749,    82,    83,    84,    85,    86,
     -44,    87,    88,    89,     0,     0,    90,    91,     0,    92,
      93,    94,     0,    81,     0,     0,    95,    96,    97,     0,
      82,    83,    84,    85,    86,     0,    87,    88,    89,     0,
       0,    90,    91,     0,    92,    93,    94,     0,     0,     0,
       0,    95,    96,    97,   290,   490,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,   290,   615,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,   290,     0,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308
};

static const yytype_int16 yycheck[] =
{
      13,    82,   235,    80,   534,    30,    21,    33,   531,   103,
      22,    92,     4,   246,   247,   109,   649,    32,   519,   149,
       4,     4,     4,     4,    10,   141,    37,     4,     4,     4,
     683,     0,     4,   580,    62,    63,     4,     5,    62,   141,
     157,   158,   158,     4,     5,     4,     4,   574,     4,    38,
     590,   844,    63,   593,     4,     5,   158,   850,     4,    62,
     838,     4,   135,   136,   137,   142,   143,   845,   145,   146,
      10,   572,   573,   146,   147,    38,   153,    17,    31,    32,
      33,    34,    35,   156,   165,   166,     4,   157,     4,   590,
      71,   161,   593,    38,     4,     5,     4,    10,    57,    57,
      59,    59,    61,    61,     4,    62,   537,    63,   189,   190,
     657,   192,     4,   141,    86,    61,     4,   141,   248,   200,
      63,   774,    51,    52,     4,   157,     4,     5,   668,   161,
     211,     4,     5,    38,   111,   662,    62,   157,     4,   159,
      62,   113,   114,   115,     3,     4,   157,   159,   116,    57,
      58,    59,    60,    61,   126,   116,   233,   658,   659,   660,
     661,   708,   157,   664,   159,   666,   116,   668,   695,    57,
     162,   157,   699,   157,   157,   256,   159,   159,   259,   260,
     162,   262,   263,   159,   159,   818,   267,   268,   269,   270,
     271,   217,   218,   274,   152,   154,   154,   830,   728,   280,
     281,   160,   160,   284,   285,   286,   116,   157,   154,   290,
     291,   292,   293,   294,   295,   296,   297,   298,   299,   300,
     301,   302,   303,   304,   305,   306,   307,   308,   309,   310,
     311,   325,   326,   327,   761,   762,   317,   318,   116,   157,
     370,   157,     4,   116,   157,     4,   154,   157,     4,   159,
     681,     4,   753,   754,   154,   756,   757,     4,     4,   139,
       4,   552,   142,   143,   144,   342,   154,    38,     3,     4,
      33,    34,    35,   139,    62,   798,   142,   143,   144,   157,
     157,   159,   159,   157,   157,   159,   159,   817,    38,   157,
     367,   159,   369,   149,   150,   151,    31,    32,    57,    58,
      38,    38,    61,    38,    39,    40,    38,    38,    40,    38,
      57,    58,    38,    57,    61,    61,    60,   253,   254,    54,
      55,    56,    29,    30,    31,    32,    33,    34,    35,    64,
      38,   178,   179,   180,    38,    70,   183,   184,   353,   630,
      75,    76,    77,    78,    79,    80,    81,    82,    38,    38,
      38,    38,    87,    88,    89,    90,    91,    92,    93,   384,
     113,   114,   115,   109,    38,    38,   101,   448,   103,   450,
     451,   452,   145,     4,     4,     4,     4,   139,     4,     4,
     142,   143,   144,   139,     4,   120,   142,   143,   144,     4,
       4,   126,   127,   474,   627,   154,   477,   478,     3,   122,
     691,     4,     4,   484,   485,     4,     4,   154,   154,   490,
     154,     4,     4,     4,   440,     4,    17,    17,    63,   158,
     155,    63,     3,     4,   159,   158,     4,   162,   163,    10,
       4,     4,     4,   510,   447,     4,   669,    75,    76,    77,
      78,    79,    80,    81,     4,     4,     4,     4,    37,    62,
      31,    32,    38,    38,    38,    38,    38,    38,    39,    40,
       6,     7,     8,     9,    10,    11,    12,    13,    14,    15,
      38,    38,    38,    54,    55,    56,    38,    38,   157,   157,
     157,   157,    71,    64,    38,    38,    38,    38,    38,    70,
      79,    38,    38,    10,    10,    10,   158,    86,     4,    62,
     158,    82,   159,   597,   157,   159,    87,    88,    89,    90,
      91,    92,    93,   159,    63,   528,   159,   106,    63,   159,
     101,   159,   103,   159,   113,   114,   115,   608,    38,     4,
      38,     4,   159,     4,     4,   159,   159,   126,   159,   120,
     159,     4,     4,   569,   570,   126,   127,     4,   158,   158,
       4,    62,     4,    38,     4,   636,    38,    63,     4,     4,
      62,    17,   159,   159,   159,    71,    38,     4,     4,   159,
     158,   652,   159,    79,   155,    17,   157,     3,     4,   159,
      86,   162,   163,   159,    10,     4,   157,    38,    17,   159,
      38,   672,   111,   687,   159,   676,    63,    38,    38,    38,
     106,   682,    99,   684,    38,    31,    32,   113,   114,   115,
      38,    38,    38,    39,    40,   848,    38,    38,     4,   852,
     126,     4,   855,   101,    37,   159,    38,   157,    54,    55,
      56,   159,    63,    38,     4,     4,   649,    38,    64,    38,
      38,    38,    38,    38,    70,    38,    38,    38,    10,   730,
     159,    17,    39,    38,    62,   159,    82,    38,    38,     4,
      10,    87,    88,    89,    90,    91,    92,    93,   157,   159,
     158,    38,   159,   159,    38,   101,   159,   103,   159,   159,
      38,   775,   112,   764,   153,   103,    63,     3,     4,   770,
     158,    81,     4,    37,   120,   159,    38,    38,   159,   159,
     126,   127,    38,    38,   159,   786,   159,    38,    38,    10,
     159,    38,    10,     4,    38,    31,    32,    17,    63,    62,
      38,   159,    38,    39,    40,    41,    71,   159,    62,   155,
      17,   157,    26,    62,    79,   159,   162,   163,    54,    55,
      56,    86,   159,   159,   159,   159,    63,     4,    64,   159,
     159,   111,   159,   159,    70,   159,   159,   159,    26,   159,
      63,   106,     4,     4,   257,   261,    82,   524,   113,   114,
     115,    87,    88,    89,    90,    91,    92,    93,   664,   528,
     841,   126,   653,   358,   231,   101,   457,   103,   834,   547,
     617,   732,     3,     4,     6,     7,     8,     9,    10,    11,
      12,    13,    14,    15,   120,   818,    17,   451,   829,    34,
     126,   127,   120,   642,   258,    -1,    -1,   830,    -1,    -1,
      31,    32,    -1,    -1,    -1,    -1,    -1,    38,    39,    40,
      -1,    -1,    -1,     3,     4,    -1,    -1,    -1,    -1,   155,
      -1,    -1,    -1,    54,    55,    56,   162,   163,    -1,    -1,
      -1,    -1,    -1,    64,    -1,    -1,    -1,    -1,    -1,    70,
      -1,    31,    32,    -1,    -1,    -1,    -1,    -1,    38,    39,
      40,    82,    -1,    -1,    -1,    -1,    87,    88,    89,    90,
      91,    92,    93,    -1,    54,    55,    56,    -1,    -1,    -1,
     101,    -1,   103,    -1,    64,    -1,    -1,    -1,    -1,    -1,
      70,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,   120,
      -1,    -1,    82,    -1,    -1,   126,   127,    87,    88,    89,
      90,    91,    92,    93,     4,    -1,    -1,    -1,    -1,    -1,
      -1,   101,    -1,   103,     6,     7,     8,     9,    10,    11,
      12,    13,    14,    15,   155,    17,    -1,    -1,    -1,    -1,
     120,   162,   163,    -1,    -1,    -1,   126,   127,    -1,    -1,
      -1,    -1,    42,    43,    44,    45,    46,    47,    -1,    -1,
      -1,    -1,    -1,    53,    -1,    -1,    -1,    57,    -1,    59,
      -1,    61,    -1,    -1,    -1,   155,    -1,    -1,    -1,    -1,
      -1,    71,   162,   163,    16,    -1,    18,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    -1,    -1,    -1,    -1,    -1,    -1,
       4,    -1,   102,    -1,   104,    -1,    -1,    -1,    -1,   109,
      -1,    -1,    -1,   113,   114,   115,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,   126,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    48,    49,    50,    -1,   148,    -1,
      -1,    -1,   152,    -1,   154,    -1,    -1,    -1,   158,    -1,
     160,    65,    66,    67,    68,    69,    -1,    71,    72,    73,
      74,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    83,
      84,    85,    86,     4,    -1,    -1,    -1,    -1,    -1,    -1,
      94,    95,    96,    97,    98,    99,   100,    -1,    -1,    -1,
      -1,   105,   106,   107,   108,    -1,    -1,    -1,    -1,   113,
     114,   115,    -1,    -1,    -1,   157,    37,   159,    -1,    -1,
      -1,    -1,   126,    -1,    -1,    -1,    -1,    48,    49,    50,
      -1,    -1,    -1,    -1,    -1,   139,    -1,    -1,    -1,    -1,
      -1,   145,    -1,    -1,    65,    66,    67,    68,    69,    -1,
      71,    72,    73,    74,   158,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    83,    84,    85,    86,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    94,    95,    96,    97,    98,    99,   100,
      -1,    -1,    -1,    -1,   105,   106,   107,   108,    -1,    -1,
      -1,    -1,   113,   114,   115,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,   126,    25,    26,    27,    28,
      29,    30,    31,    32,    33,    34,    35,    16,   139,    18,
      19,    20,    21,    22,    23,    24,    25,    26,    27,    28,
      29,    30,    31,    32,    33,    34,    35,   158,    16,    -1,
      18,    19,    20,    21,    22,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,    16,    -1,
      18,    19,    20,    21,    22,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,    16,    -1,
      18,    19,    20,    21,    22,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,    16,    -1,
      18,    19,    20,    21,    22,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,    16,    -1,
      18,    19,    20,    21,    22,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,    16,    -1,
      18,    19,    20,    21,    22,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,    -1,    16,
     159,    18,    19,    20,    21,    22,    23,    24,    25,    26,
      27,    28,    29,    30,    31,    32,    33,    34,    35,    -1,
      16,   159,    18,    19,    20,    21,    22,    23,    24,    25,
      26,    27,    28,    29,    30,    31,    32,    33,    34,    35,
      16,   159,    18,    19,    20,    21,    22,    23,    24,    25,
      26,    27,    28,    29,    30,    31,    32,    33,    34,    35,
      16,   159,    18,    19,    20,    21,    22,    23,    24,    25,
      26,    27,    28,    29,    30,    31,    32,    33,    34,    35,
      16,   159,    18,    19,    20,    21,    22,    23,    24,    25,
      26,    27,    28,    29,    30,    31,    32,    33,    34,    35,
      16,   159,    18,    19,    20,    21,    22,    23,    24,    25,
      26,    27,    28,    29,    30,    31,    32,    33,    34,    35,
      16,   159,    18,    19,    20,    21,    22,    23,    24,    25,
      26,    27,    28,    29,    30,    31,    32,    33,    34,    35,
      -1,    16,   159,    18,    19,    20,    21,    22,    23,    24,
      25,    26,    27,    28,    29,    30,    31,    32,    33,    34,
      35,    -1,    16,   159,    18,    19,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    35,    16,   159,    18,    19,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    35,    16,   159,    18,    19,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    35,    16,   159,    18,    19,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    35,    16,   159,    18,    19,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    35,    16,   159,    18,    19,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    35,    -1,    16,   159,    18,    19,    20,    21,    22,
      23,    24,    25,    26,    27,    28,    29,    30,    31,    32,
      33,    34,    35,    -1,    16,   159,    18,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    16,   159,    18,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    16,   159,    18,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    16,   159,    18,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    -1,   159,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    35,    16,   157,    18,    19,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    35,    -1,    16,   157,    18,    19,    20,    21,    22,
      23,    24,    25,    26,    27,    28,    29,    30,    31,    32,
      33,    34,    35,    -1,    -1,   157,    -1,    -1,    -1,    -1,
      -1,    -1,     4,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,   157,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,     4,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,   157,    -1,    39,    21,    22,
      23,    24,    25,    26,    27,    28,    29,    30,    31,    32,
      33,    34,    35,    -1,    -1,   157,    -1,    -1,    -1,    -1,
      37,    -1,    39,    -1,    -1,    -1,    -1,    -1,    16,    71,
      18,    19,    20,    21,    22,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,    -1,    -1,
      38,    -1,    -1,   157,    71,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,   110,    -1,
      -1,    -1,    -1,    -1,   157,   117,   118,   119,   120,   121,
     122,   123,   124,   125,    -1,    -1,   128,   129,    -1,   131,
     132,   133,    -1,   110,    -1,    -1,   138,   139,   140,    -1,
     117,   118,   119,   120,   121,    -1,   123,   124,   125,    -1,
      -1,   128,   129,    -1,   131,   132,   133,    -1,    -1,    -1,
      -1,   138,   139,   140,    16,    17,    18,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    16,    17,    18,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    16,    -1,    18,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    30,    31,
      32,    33,    34,    35,    22,    23,    24,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35
};

/* YYSTOS[STATE-NUM] -- The symbol kind of the accessing symbol of
   state STATE-NUM.  */
static const yytype_int16 yystos[] =
{
       0,   135,   136,   137,   146,   147,   156,   165,   179,   180,
     169,   170,   167,   168,   288,   289,   300,   301,   283,   284,
       0,   181,   171,     4,   113,   114,   115,   219,    62,   141,
     292,   293,   302,    62,   285,   286,    48,    49,    50,    65,
      66,    67,    68,    69,    71,    72,    73,    74,    83,    84,
      85,    86,    94,    95,    96,    97,    98,    99,   100,   105,
     106,   107,   108,   126,   139,   158,   182,   193,   195,   219,
     221,   232,   233,   235,   237,   275,   290,   291,     4,    39,
      71,   110,   117,   118,   119,   120,   121,   123,   124,   125,
     128,   129,   131,   132,   133,   138,   139,   140,   172,     6,
       7,     8,     9,    10,    11,    12,    13,    14,    15,   217,
      38,    38,    38,     4,   139,   142,   143,   144,   295,   296,
      62,   293,     4,   195,   303,   143,   144,   287,   296,   286,
      62,    62,    51,    52,    38,    38,     4,   166,    62,    38,
      38,    38,    38,    38,    38,    38,    38,    38,    38,    38,
      38,   183,   184,    38,   196,    38,   157,   158,   218,   145,
       4,   166,     4,     3,     4,    31,    32,    38,    39,    40,
      54,    55,    56,    64,    70,    82,    87,    88,    89,    90,
      91,    92,    93,   101,   103,   120,   126,   127,   155,   162,
     163,   243,     4,     4,   176,     4,   175,   174,     4,     4,
       4,   243,     4,     3,     4,   177,     4,   178,     4,   122,
     241,   242,   241,     4,     4,     4,     4,    17,    17,    63,
     158,   295,    17,    63,   158,   194,   276,     4,     4,     4,
       4,   185,     4,    71,   222,   223,   224,     4,     4,     4,
     166,   166,     4,   166,   159,   166,   234,   236,     4,   238,
     238,   187,   188,    38,    38,   166,    38,   186,    62,    10,
     157,   173,    10,   157,   243,   243,   243,    38,    38,    38,
      38,    38,   244,    38,    38,   239,   240,   239,   239,   239,
      38,    38,   239,   239,    38,    38,    38,    38,   243,   243,
      16,    18,    19,    20,    21,    22,    23,    24,    25,    26,
      27,    28,    29,    30,    31,    32,    33,    34,    35,   157,
      10,   157,   243,   157,   157,     4,   157,    10,   157,   243,
     157,   157,     4,   157,   243,    10,    10,    10,    62,   296,
     296,   158,     4,   139,   142,   143,   144,    63,   304,   158,
       4,    63,    71,    79,   106,   195,   252,     4,    63,   277,
     157,   159,   159,   181,   225,   166,    63,   157,   220,   157,
     159,   159,   159,   159,   159,   159,   159,   220,   159,   220,
     157,   238,   159,   159,   159,     4,     5,   116,   189,   187,
     187,   159,   243,   178,   292,   243,   243,   171,   243,   243,
     159,   243,   243,   243,   243,   243,    38,     4,   243,    38,
     243,   243,   243,   243,   243,     4,   243,   243,   243,   243,
     243,   243,   243,   243,   243,   243,   243,   243,   243,   243,
     243,   243,   243,   243,   243,   243,   243,   243,     4,     4,
       4,   243,   243,     3,     4,     4,     4,   241,   241,   241,
     298,   158,   158,     4,   141,   158,   294,    62,   253,   166,
     257,   261,   278,     4,    37,    38,   229,   226,   224,     4,
     166,   166,   238,    38,     4,     5,   116,   157,   159,   159,
     157,   159,    63,    37,   157,   159,   159,   157,   157,   159,
       4,   159,   159,     4,   157,   157,   159,   157,   159,   159,
      17,   159,   159,   159,   296,   144,    62,   141,   158,     4,
      42,    43,    44,    45,    46,    47,    53,    57,    59,    61,
      71,   102,   104,   109,   126,   148,   152,   154,   158,   160,
     197,   198,   199,   200,   203,   206,   207,   209,   212,   213,
     214,   219,    38,    41,   243,   265,   266,   263,    17,   243,
     267,   266,   243,   280,   157,     4,   162,   230,   231,    17,
     222,   159,   190,    38,     4,     5,   116,     4,   243,   243,
     243,   245,   159,   243,   243,     4,   243,   158,   299,    17,
     297,     4,    38,    38,    38,   166,    38,   210,    38,    38,
      38,     4,    57,    58,    59,    60,    61,   199,   201,   205,
      38,     4,    57,   160,   200,   209,    63,    38,   218,    75,
      76,    77,    78,    79,    80,    81,   159,   264,    38,    38,
     265,    17,   111,   247,   194,    17,    99,   268,   262,     4,
     111,   281,     4,     4,   159,   231,   101,   227,    37,   189,
     192,    38,   159,   159,   159,   159,   157,   159,   159,   159,
      63,   296,   296,    61,   109,   199,   199,    57,   198,   211,
     215,   241,    38,   208,     4,   202,   197,   204,    38,    38,
      38,    38,    38,   161,   220,   205,    38,   205,    38,   305,
     241,    38,    10,   159,   243,    17,    38,    39,   248,    37,
     247,    62,    38,   282,    38,   279,   159,    10,   220,   159,
     189,   191,   243,   158,   299,    38,   159,   159,   159,    38,
     159,   213,   159,   243,     4,   206,    22,   159,   159,   197,
      57,    58,   199,    57,    58,   199,   199,   199,    57,    60,
     201,   159,   161,   205,   220,   159,    81,   243,   159,   243,
      38,   153,   249,   112,   250,   194,   243,   281,   243,   158,
     241,   103,   228,   159,   189,   159,    63,   198,    37,   157,
     159,     4,   197,    38,    38,   159,    38,    38,   159,   159,
     159,    38,    38,   159,    10,    40,   265,   159,   243,   250,
      38,   258,    63,   159,   159,    10,   159,   159,     4,   199,
     199,   199,   199,   198,   198,   243,    38,    17,   159,   149,
     150,   151,   251,   243,    62,   281,   241,   159,   159,   159,
     159,   159,   159,   159,   159,   159,   243,   254,   159,   259,
     218,   159,   159,   159,   159,   159,   159,   159,    62,   271,
     265,   213,     4,    63,    17,    63,   272,    26,   269,   255,
      62,     4,   111,   246,   269,   213,    26,   270,   246,    63,
       4,    10,    17,   216,   270,   273,   215,     4,   260,   216,
     270,   220,   256,   216,   220,   274,   220
};

/* YYR1[RULE-NUM] -- Symbol kind of the left-hand side of rule RULE-NUM.  */
static const yytype_int16 yyr1[] =
{
       0,   164,   165,   165,   165,   165,   165,   165,   166,   168,
     167,   170,   169,   171,   171,   172,   172,   172,   172,   172,
     172,   172,   172,   172,   172,   172,   172,   172,   172,   172,
     172,   172,   172,   172,   172,   172,   172,   172,   172,   172,
     172,   173,   172,   172,   172,   174,   174,   174,   175,   175,
     176,   176,   177,   177,   177,   178,   178,   178,   180,   179,
     181,   181,   182,   182,   182,   182,   182,   182,   182,   182,
     182,   182,   182,   182,   182,   182,   182,   182,   182,   182,
     182,   182,   183,   182,   184,   182,   182,   185,   182,   182,
     182,   186,   182,   182,   182,   182,   182,   188,   187,   189,
     189,   189,   189,   189,   189,   190,   189,   191,   189,   192,
     189,   193,   194,   194,   194,   195,   195,   196,   195,   197,
     198,   198,   199,   199,   200,   200,   200,   200,   201,   201,
     201,   201,   201,   201,   201,   201,   201,   201,   201,   202,
     202,   203,   204,   204,   205,   205,   206,   206,   206,   206,
     206,   206,   207,   208,   207,   209,   209,   209,   209,   209,
     209,   209,   209,   209,   209,   210,   209,   211,   209,   212,
     212,   213,   213,   214,   214,   214,   214,   214,   215,   216,
     216,   217,   217,   217,   217,   217,   217,   217,   217,   217,
     218,   218,   219,   219,   219,   219,   219,   220,   220,   221,
     222,   222,   223,   223,   225,   224,   226,   224,   227,   228,
     229,   229,   230,   230,   231,   231,   232,   233,   233,   234,
     234,   235,   236,   236,   237,   237,   238,   238,   238,   240,
     239,   242,   241,   243,   243,   243,   243,   243,   243,   243,
     243,   243,   243,   243,   243,   243,   243,   243,   243,   243,
     243,   243,   243,   243,   243,   243,   243,   243,   243,   243,
     243,   243,   243,   243,   243,   243,   243,   243,   243,   243,
     243,   243,   244,   245,   243,   243,   243,   243,   243,   243,
     243,   243,   243,   246,   246,   247,   247,   248,   248,   249,
     249,   250,   250,   251,   251,   251,   251,   253,   254,   255,
     256,   252,   257,   258,   259,   260,   252,   261,   262,   252,
     263,   252,   264,   264,   264,   264,   264,   264,   264,   264,
     265,   265,   265,   266,   266,   266,   266,   267,   267,   268,
     268,   269,   269,   270,   270,   271,   272,   273,   274,   271,
     275,   276,   276,   278,   279,   277,   280,   281,   281,   281,
     282,   282,   284,   283,   285,   285,   286,   287,   289,   288,
     291,   290,   292,   292,   293,   293,   293,   294,   294,   295,
     295,   295,   295,   295,   296,   296,   296,   296,   297,   296,
     298,   296,   296,   296,   296,   296,   296,   296,   299,   299,
     301,   300,   302,   302,   302,   304,   305,   303
};

/* YYR2[RULE-NUM] -- Number of symbols on the right-hand side of rule RULE-NUM.  */
static const yytype_int8 yyr2[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     1,     0,
       2,     0,     2,     3,     0,     2,     4,     1,     1,     2,
       1,     4,     4,     3,     2,     4,     3,     4,     4,     4,
       4,     4,     2,     2,     2,     4,     4,     2,     2,     2,
       2,     0,     5,     2,     0,     3,     2,     0,     1,     3,
       1,     3,     0,     1,     3,     1,     2,     3,     0,     2,
       2,     0,     1,     1,     1,     1,     1,     1,     1,     1,
       1,     1,     4,     4,     4,     4,     8,     4,     1,     1,
       1,     4,     0,     5,     0,     5,     4,     0,     5,     4,
       4,     0,     5,     3,     3,     6,     4,     0,     2,     1,
       3,     2,     1,     3,     2,     0,     5,     0,     7,     0,
       6,     4,     2,     2,     0,     4,     2,     0,     7,     1,
       1,     5,     1,     4,     1,     4,     4,     7,     1,     4,
       4,     4,     7,     7,     7,     7,     4,     7,     7,     1,
       3,     4,     2,     1,     3,     1,     1,     2,     3,     4,
       4,     5,     1,     0,     5,     1,     2,     1,     1,     4,
       1,     4,     2,     4,     1,     0,     8,     0,     5,     2,
       1,     0,     1,     1,     1,     1,     1,     1,     1,     2,
       0,     1,     1,     1,     1,     1,     1,     1,     1,     1,
       1,     1,     3,     3,     6,     6,     6,     1,     0,     4,
       1,     0,     3,     1,     0,     7,     0,     5,     3,     3,
       0,     3,     1,     2,     1,     2,     4,     4,     3,     3,
       1,     4,     3,     0,     1,     1,     0,     2,     3,     0,
       4,     0,     2,     2,     3,     4,     2,     2,     2,     3,
       3,     3,     3,     3,     3,     3,     3,     3,     3,     3,
       3,     3,     3,     3,     3,     5,     3,     3,     4,     1,
       1,     2,     2,     2,     2,     4,     4,     4,     6,     6,
       6,     4,     0,     0,     8,     4,     1,     6,     6,     6,
       2,     2,     4,     3,     0,     4,     0,     4,     0,     1,
       0,     4,     0,     1,     1,     1,     0,     0,     0,     0,
       0,    19,     0,     0,     0,     0,    17,     0,     0,     7,
       0,     5,     1,     1,     1,     1,     1,     6,     1,     3,
       3,     0,     2,     3,     2,     6,    10,     2,     1,     0,
       1,     2,     0,     0,     3,     0,     0,     0,     0,    11,
       4,     0,     2,     0,     0,     6,     1,     0,     3,     5,
       0,     3,     0,     2,     1,     2,     4,     2,     0,     2,
       0,     5,     1,     2,     4,     5,     6,     1,     2,     0,
       2,     4,     4,     8,     1,     1,     3,     3,     0,     9,
       0,     7,     1,     3,     1,     3,     1,     3,     0,     1,
       0,     2,     2,     2,     0,     0,     0,     8
};


enum { YYENOMEM = -2 };

#define yyerrok         (yyerrstatus = 0)
#define yyclearin       (yychar = YYEMPTY)

#define YYACCEPT        goto yyacceptlab
#define YYABORT         goto yyabortlab
#define YYERROR         goto yyerrorlab
#define YYNOMEM         goto yyexhaustedlab


#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)                                    \
  do                                                              \
    if (yychar == YYEMPTY)                                        \
      {                                                           \
        yychar = (Token);                                         \
        yylval = (Value);                                         \
        YYPOPSTACK (yylen);                                       \
        yystate = *yyssp;                                         \
        goto yybackup;                                            \
      }                                                           \
    else                                                          \
      {                                                           \
        yyerror (YY_("syntax error: cannot back up")); \
        YYERROR;                                                  \
      }                                                           \
  while (0)

/* Backward compatibility with an undocumented macro.
   Use YYerror or YYUNDEF. */
#define YYERRCODE YYUNDEF


/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)                        \
do {                                            \
  if (yydebug)                                  \
    YYFPRINTF Args;                             \
} while (0)




# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)                    \
do {                                                                      \
  if (yydebug)                                                            \
    {                                                                     \
      YYFPRINTF (stderr, "%s ", Title);                                   \
      yy_symbol_print (stderr,                                            \
                  Kind, Value); \
      YYFPRINTF (stderr, "\n");                                           \
    }                                                                     \
} while (0)


/*-----------------------------------.
| Print this symbol's value on YYO.  |
`-----------------------------------*/

static void
yy_symbol_value_print (FILE *yyo,
                       yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep)
{
  FILE *yyoutput = yyo;
  YY_USE (yyoutput);
  if (!yyvaluep)
    return;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YY_USE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/*---------------------------.
| Print this symbol on YYO.  |
`---------------------------*/

static void
yy_symbol_print (FILE *yyo,
                 yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep)
{
  YYFPRINTF (yyo, "%s %s (",
             yykind < YYNTOKENS ? "token" : "nterm", yysymbol_name (yykind));

  yy_symbol_value_print (yyo, yykind, yyvaluep);
  YYFPRINTF (yyo, ")");
}

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

static void
yy_stack_print (yy_state_t *yybottom, yy_state_t *yytop)
{
  YYFPRINTF (stderr, "Stack now");
  for (; yybottom <= yytop; yybottom++)
    {
      int yybot = *yybottom;
      YYFPRINTF (stderr, " %d", yybot);
    }
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)                            \
do {                                                            \
  if (yydebug)                                                  \
    yy_stack_print ((Bottom), (Top));                           \
} while (0)


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

static void
yy_reduce_print (yy_state_t *yyssp, YYSTYPE *yyvsp,
                 int yyrule)
{
  int yylno = yyrline[yyrule];
  int yynrhs = yyr2[yyrule];
  int yyi;
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %d):\n",
             yyrule - 1, yylno);
  /* The symbols being reduced.  */
  for (yyi = 0; yyi < yynrhs; yyi++)
    {
      YYFPRINTF (stderr, "   $%d = ", yyi + 1);
      yy_symbol_print (stderr,
                       YY_ACCESSING_SYMBOL (+yyssp[yyi + 1 - yynrhs]),
                       &yyvsp[(yyi + 1) - (yynrhs)]);
      YYFPRINTF (stderr, "\n");
    }
}

# define YY_REDUCE_PRINT(Rule)          \
do {                                    \
  if (yydebug)                          \
    yy_reduce_print (yyssp, yyvsp, Rule); \
} while (0)

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args) ((void) 0)
# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   YYSTACK_ALLOC_MAXIMUM < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif






/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

static void
yydestruct (const char *yymsg,
            yysymbol_kind_t yykind, YYSTYPE *yyvaluep)
{
  YY_USE (yyvaluep);
  if (!yymsg)
    yymsg = "Deleting";
  YY_SYMBOL_PRINT (yymsg, yykind, yyvaluep, yylocationp);

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YY_USE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/* Lookahead token kind.  */
int yychar;

/* The semantic value of the lookahead symbol.  */
YYSTYPE yylval;
/* Number of syntax errors so far.  */
int yynerrs;




/*----------.
| yyparse.  |
`----------*/

int
yyparse (void)
{
    yy_state_fast_t yystate = 0;
    /* Number of tokens to shift before error messages enabled.  */
    int yyerrstatus = 0;

    /* Refer to the stacks through separate pointers, to allow yyoverflow
       to reallocate them elsewhere.  */

    /* Their size.  */
    YYPTRDIFF_T yystacksize = YYINITDEPTH;

    /* The state stack: array, bottom, top.  */
    yy_state_t yyssa[YYINITDEPTH];
    yy_state_t *yyss = yyssa;
    yy_state_t *yyssp = yyss;

    /* The semantic value stack: array, bottom, top.  */
    YYSTYPE yyvsa[YYINITDEPTH];
    YYSTYPE *yyvs = yyvsa;
    YYSTYPE *yyvsp = yyvs;

  int yyn;
  /* The return value of yyparse.  */
  int yyresult;
  /* Lookahead symbol kind.  */
  yysymbol_kind_t yytoken = YYSYMBOL_YYEMPTY;
  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;



#define YYPOPSTACK(N)   (yyvsp -= (N), yyssp -= (N))

  /* The number of symbols on the RHS of the reduced rule.
     Keep to zero when no symbol should be popped.  */
  int yylen = 0;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yychar = YYEMPTY; /* Cause a token to be read.  */

  goto yysetstate;


/*------------------------------------------------------------.
| yynewstate -- push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed.  So pushing a state here evens the stacks.  */
  yyssp++;


/*--------------------------------------------------------------------.
| yysetstate -- set current state (the top of the stack) to yystate.  |
`--------------------------------------------------------------------*/
yysetstate:
  YYDPRINTF ((stderr, "Entering state %d\n", yystate));
  YY_ASSERT (0 <= yystate && yystate < YYNSTATES);
  YY_IGNORE_USELESS_CAST_BEGIN
  *yyssp = YY_CAST (yy_state_t, yystate);
  YY_IGNORE_USELESS_CAST_END
  YY_STACK_PRINT (yyss, yyssp);

  if (yyss + yystacksize - 1 <= yyssp)
#if !defined yyoverflow && !defined YYSTACK_RELOCATE
    YYNOMEM;
#else
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYPTRDIFF_T yysize = yyssp - yyss + 1;

# if defined yyoverflow
      {
        /* Give user a chance to reallocate the stack.  Use copies of
           these so that the &'s don't force the real ones into
           memory.  */
        yy_state_t *yyss1 = yyss;
        YYSTYPE *yyvs1 = yyvs;

        /* Each stack pointer address is followed by the size of the
           data in use in that stack, in bytes.  This used to be a
           conditional around just the two extra args, but that might
           be undefined if yyoverflow is a macro.  */
        yyoverflow (YY_("memory exhausted"),
                    &yyss1, yysize * YYSIZEOF (*yyssp),
                    &yyvs1, yysize * YYSIZEOF (*yyvsp),
                    &yystacksize);
        yyss = yyss1;
        yyvs = yyvs1;
      }
# else /* defined YYSTACK_RELOCATE */
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
        YYNOMEM;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
        yystacksize = YYMAXDEPTH;

      {
        yy_state_t *yyss1 = yyss;
        union yyalloc *yyptr =
          YY_CAST (union yyalloc *,
                   YYSTACK_ALLOC (YY_CAST (YYSIZE_T, YYSTACK_BYTES (yystacksize))));
        if (! yyptr)
          YYNOMEM;
        YYSTACK_RELOCATE (yyss_alloc, yyss);
        YYSTACK_RELOCATE (yyvs_alloc, yyvs);
#  undef YYSTACK_RELOCATE
        if (yyss1 != yyssa)
          YYSTACK_FREE (yyss1);
      }
# endif

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;

      YY_IGNORE_USELESS_CAST_BEGIN
      YYDPRINTF ((stderr, "Stack size increased to %ld\n",
                  YY_CAST (long, yystacksize)));
      YY_IGNORE_USELESS_CAST_END

      if (yyss + yystacksize - 1 <= yyssp)
        YYABORT;
    }
#endif /* !defined yyoverflow && !defined YYSTACK_RELOCATE */


  if (yystate == YYFINAL)
    YYACCEPT;

  goto yybackup;


/*-----------.
| yybackup.  |
`-----------*/
yybackup:
  /* Do appropriate processing given the current state.  Read a
     lookahead token if we need one and don't already have one.  */

  /* First try to decide what to do without reference to lookahead token.  */
  yyn = yypact[yystate];
  if (yypact_value_is_default (yyn))
    goto yydefault;

  /* Not known => get a lookahead token if don't already have one.  */

  /* YYCHAR is either empty, or end-of-input, or a valid lookahead.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token\n"));
      yychar = yylex ();
    }

  if (yychar <= YYEOF)
    {
      yychar = YYEOF;
      yytoken = YYSYMBOL_YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else if (yychar == YYerror)
    {
      /* The scanner already issued an error message, process directly
         to error recovery.  But do not keep the error token as
         lookahead, it is too special and may lead us to an endless
         loop in error recovery. */
      yychar = YYUNDEF;
      yytoken = YYSYMBOL_YYerror;
      goto yyerrlab1;
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YY_SYMBOL_PRINT ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yytable_value_is_error (yyn))
        goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  /* Shift the lookahead token.  */
  YY_SYMBOL_PRINT ("Shifting", yytoken, &yylval, &yylloc);
  yystate = yyn;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END

  /* Discard the shifted token.  */
  yychar = YYEMPTY;
  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     '$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];


  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
  case 9: /* $@1: %empty  */
#line 185 "ldgram.y"
                { ldlex_expression(); }
#line 2631 "ldgram.c"
    break;

  case 10: /* defsym_expr: $@1 assignment  */
#line 187 "ldgram.y"
                { ldlex_popstate(); }
#line 2637 "ldgram.c"
    break;

  case 11: /* $@2: %empty  */
#line 192 "ldgram.y"
                {
		  ldlex_mri_script ();
		  PUSH_ERROR (_("MRI style script"));
		}
#line 2646 "ldgram.c"
    break;

  case 12: /* mri_script_file: $@2 mri_script_lines  */
#line 197 "ldgram.y"
                {
		  ldlex_popstate ();
		  mri_draw_tree ();
		  POP_ERROR ();
		}
#line 2656 "ldgram.c"
    break;

  case 17: /* mri_script_command: NAME  */
#line 212 "ldgram.y"
                        {
			fatal (_("%P: unrecognised keyword in MRI style script '%s'\n"), (yyvsp[0].name));
			}
#line 2664 "ldgram.c"
    break;

  case 18: /* mri_script_command: LIST  */
#line 215 "ldgram.y"
                        {
			config.map_filename = "-";
			}
#line 2672 "ldgram.c"
    break;

  case 21: /* mri_script_command: PUBLIC NAME '=' exp  */
#line 221 "ldgram.y"
                        { mri_public((yyvsp[-2].name), (yyvsp[0].etree)); }
#line 2678 "ldgram.c"
    break;

  case 22: /* mri_script_command: PUBLIC NAME ',' exp  */
#line 223 "ldgram.y"
                        { mri_public((yyvsp[-2].name), (yyvsp[0].etree)); }
#line 2684 "ldgram.c"
    break;

  case 23: /* mri_script_command: PUBLIC NAME exp  */
#line 225 "ldgram.y"
                        { mri_public((yyvsp[-1].name), (yyvsp[0].etree)); }
#line 2690 "ldgram.c"
    break;

  case 24: /* mri_script_command: FORMAT NAME  */
#line 227 "ldgram.y"
                        { mri_format((yyvsp[0].name)); }
#line 2696 "ldgram.c"
    break;

  case 25: /* mri_script_command: SECT NAME ',' exp  */
#line 229 "ldgram.y"
                        { mri_output_section((yyvsp[-2].name), (yyvsp[0].etree));}
#line 2702 "ldgram.c"
    break;

  case 26: /* mri_script_command: SECT NAME exp  */
#line 231 "ldgram.y"
                        { mri_output_section((yyvsp[-1].name), (yyvsp[0].etree));}
#line 2708 "ldgram.c"
    break;

  case 27: /* mri_script_command: SECT NAME '=' exp  */
#line 233 "ldgram.y"
                        { mri_output_section((yyvsp[-2].name), (yyvsp[0].etree));}
#line 2714 "ldgram.c"
    break;

  case 28: /* mri_script_command: ALIGN_K NAME '=' exp  */
#line 235 "ldgram.y"
                        { mri_align((yyvsp[-2].name),(yyvsp[0].etree)); }
#line 2720 "ldgram.c"
    break;

  case 29: /* mri_script_command: ALIGN_K NAME ',' exp  */
#line 237 "ldgram.y"
                        { mri_align((yyvsp[-2].name),(yyvsp[0].etree)); }
#line 2726 "ldgram.c"
    break;

  case 30: /* mri_script_command: ALIGNMOD NAME '=' exp  */
#line 239 "ldgram.y"
                        { mri_alignmod((yyvsp[-2].name),(yyvsp[0].etree)); }
#line 2732 "ldgram.c"
    break;

  case 31: /* mri_script_command: ALIGNMOD NAME ',' exp  */
#line 241 "ldgram.y"
                        { mri_alignmod((yyvsp[-2].name),(yyvsp[0].etree)); }
#line 2738 "ldgram.c"
    break;

  case 34: /* mri_script_command: NAMEWORD NAME  */
#line 245 "ldgram.y"
                        { mri_name((yyvsp[0].name)); }
#line 2744 "ldgram.c"
    break;

  case 35: /* mri_script_command: ALIAS NAME ',' NAME  */
#line 247 "ldgram.y"
                        { mri_alias((yyvsp[-2].name),(yyvsp[0].name),0);}
#line 2750 "ldgram.c"
    break;

  case 36: /* mri_script_command: ALIAS NAME ',' INT  */
#line 249 "ldgram.y"
                        { mri_alias ((yyvsp[-2].name), 0, (int) (yyvsp[0].bigint).integer); }
#line 2756 "ldgram.c"
    break;

  case 37: /* mri_script_command: BASE exp  */
#line 251 "ldgram.y"
                        { mri_base((yyvsp[0].etree)); }
#line 2762 "ldgram.c"
    break;

  case 38: /* mri_script_command: TRUNCATE INT  */
#line 253 "ldgram.y"
                { mri_truncate ((unsigned int) (yyvsp[0].bigint).integer); }
#line 2768 "ldgram.c"
    break;

  case 41: /* $@3: %empty  */
#line 257 "ldgram.y"
                { ldfile_open_command_file ((yyvsp[0].name)); }
#line 2774 "ldgram.c"
    break;

  case 43: /* mri_script_command: START NAME  */
#line 260 "ldgram.y"
                { lang_add_entry ((yyvsp[0].name), false); }
#line 2780 "ldgram.c"
    break;

  case 45: /* ordernamelist: ordernamelist ',' NAME  */
#line 265 "ldgram.y"
                                             { mri_order((yyvsp[0].name)); }
#line 2786 "ldgram.c"
    break;

  case 46: /* ordernamelist: ordernamelist NAME  */
#line 266 "ldgram.y"
                                          { mri_order((yyvsp[0].name)); }
#line 2792 "ldgram.c"
    break;

  case 48: /* mri_load_name_list: NAME  */
#line 272 "ldgram.y"
                        { mri_load((yyvsp[0].name)); }
#line 2798 "ldgram.c"
    break;

  case 49: /* mri_load_name_list: mri_load_name_list ',' NAME  */
#line 273 "ldgram.y"
                                            { mri_load((yyvsp[0].name)); }
#line 2804 "ldgram.c"
    break;

  case 50: /* mri_abs_name_list: NAME  */
#line 278 "ldgram.y"
                        { mri_only_load((yyvsp[0].name)); }
#line 2810 "ldgram.c"
    break;

  case 51: /* mri_abs_name_list: mri_abs_name_list ',' NAME  */
#line 280 "ldgram.y"
                        { mri_only_load((yyvsp[0].name)); }
#line 2816 "ldgram.c"
    break;

  case 52: /* casesymlist: %empty  */
#line 284 "ldgram.y"
                      { (yyval.name) = NULL; }
#line 2822 "ldgram.c"
    break;

  case 55: /* extern_name_list: NAME  */
#line 291 "ldgram.y"
                        { ldlang_add_undef ((yyvsp[0].name), false); }
#line 2828 "ldgram.c"
    break;

  case 56: /* extern_name_list: extern_name_list NAME  */
#line 293 "ldgram.y"
                        { ldlang_add_undef ((yyvsp[0].name), false); }
#line 2834 "ldgram.c"
    break;

  case 57: /* extern_name_list: extern_name_list ',' NAME  */
#line 295 "ldgram.y"
                        { ldlang_add_undef ((yyvsp[0].name), false); }
#line 2840 "ldgram.c"
    break;

  case 58: /* $@4: %empty  */
#line 299 "ldgram.y"
        { ldlex_script (); }
#line 2846 "ldgram.c"
    break;

  case 59: /* script_file: $@4 ifile_list  */
#line 301 "ldgram.y"
        { ldlex_popstate (); }
#line 2852 "ldgram.c"
    break;

  case 72: /* ifile_p1: TARGET_K '(' NAME ')'  */
#line 322 "ldgram.y"
                { lang_add_target((yyvsp[-1].name)); }
#line 2858 "ldgram.c"
    break;

  case 73: /* ifile_p1: SEARCH_DIR '(' filename ')'  */
#line 324 "ldgram.y"
                { ldfile_add_library_path ((yyvsp[-1].name), false); }
#line 2864 "ldgram.c"
    break;

  case 74: /* ifile_p1: OUTPUT '(' filename ')'  */
#line 326 "ldgram.y"
                { lang_add_output((yyvsp[-1].name), 1); }
#line 2870 "ldgram.c"
    break;

  case 75: /* ifile_p1: OUTPUT_FORMAT '(' NAME ')'  */
#line 328 "ldgram.y"
                  { lang_add_output_format ((yyvsp[-1].name), (char *) NULL,
					    (char *) NULL, 1); }
#line 2877 "ldgram.c"
    break;

  case 76: /* ifile_p1: OUTPUT_FORMAT '(' NAME ',' NAME ',' NAME ')'  */
#line 331 "ldgram.y"
                  { lang_add_output_format ((yyvsp[-5].name), (yyvsp[-3].name), (yyvsp[-1].name), 1); }
#line 2883 "ldgram.c"
    break;

  case 77: /* ifile_p1: OUTPUT_ARCH '(' NAME ')'  */
#line 333 "ldgram.y"
                  { ldfile_set_output_arch ((yyvsp[-1].name), bfd_arch_unknown); }
#line 2889 "ldgram.c"
    break;

  case 78: /* ifile_p1: FORCE_COMMON_ALLOCATION  */
#line 335 "ldgram.y"
                { command_line.force_common_definition = true ; }
#line 2895 "ldgram.c"
    break;

  case 79: /* ifile_p1: FORCE_GROUP_ALLOCATION  */
#line 337 "ldgram.y"
                { command_line.force_group_allocation = true ; }
#line 2901 "ldgram.c"
    break;

  case 80: /* ifile_p1: INHIBIT_COMMON_ALLOCATION  */
#line 339 "ldgram.y"
                { link_info.inhibit_common_definition = true ; }
#line 2907 "ldgram.c"
    break;

  case 82: /* $@5: %empty  */
#line 342 "ldgram.y"
                  { lang_enter_group (); }
#line 2913 "ldgram.c"
    break;

  case 83: /* ifile_p1: GROUP $@5 '(' input_list ')'  */
#line 344 "ldgram.y"
                  { lang_leave_group (); }
#line 2919 "ldgram.c"
    break;

  case 84: /* $@6: %empty  */
#line 346 "ldgram.y"
                  { lang_enter_lib (); }
#line 2925 "ldgram.c"
    break;

  case 85: /* ifile_p1: LIB $@6 '(' input_list ')'  */
#line 348 "ldgram.y"
                  { lang_leave_lib (); }
#line 2931 "ldgram.c"
    break;

  case 86: /* ifile_p1: MAP '(' filename ')'  */
#line 350 "ldgram.y"
                { lang_add_map((yyvsp[-1].name)); }
#line 2937 "ldgram.c"
    break;

  case 87: /* $@7: %empty  */
#line 352 "ldgram.y"
                { ldfile_open_command_file ((yyvsp[0].name)); }
#line 2943 "ldgram.c"
    break;

  case 89: /* ifile_p1: NOCROSSREFS '(' nocrossref_list ')'  */
#line 355 "ldgram.y"
                {
		  lang_add_nocrossref ((yyvsp[-1].nocrossref));
		}
#line 2951 "ldgram.c"
    break;

  case 90: /* ifile_p1: NOCROSSREFS_TO '(' nocrossref_list ')'  */
#line 359 "ldgram.y"
                {
		  lang_add_nocrossref_to ((yyvsp[-1].nocrossref));
		}
#line 2959 "ldgram.c"
    break;

  case 91: /* $@8: %empty  */
#line 362 "ldgram.y"
                           { ldlex_expression (); }
#line 2965 "ldgram.c"
    break;

  case 92: /* ifile_p1: EXTERN '(' $@8 extern_name_list ')'  */
#line 363 "ldgram.y"
                        { ldlex_popstate (); }
#line 2971 "ldgram.c"
    break;

  case 93: /* ifile_p1: INSERT_K AFTER NAME  */
#line 365 "ldgram.y"
                { lang_add_insert ((yyvsp[0].name), 0); }
#line 2977 "ldgram.c"
    break;

  case 94: /* ifile_p1: INSERT_K BEFORE NAME  */
#line 367 "ldgram.y"
                { lang_add_insert ((yyvsp[0].name), 1); }
#line 2983 "ldgram.c"
    break;

  case 95: /* ifile_p1: REGION_ALIAS '(' NAME ',' NAME ')'  */
#line 369 "ldgram.y"
                { lang_memory_region_alias ((yyvsp[-3].name), (yyvsp[-1].name)); }
#line 2989 "ldgram.c"
    break;

  case 96: /* ifile_p1: LD_FEATURE '(' NAME ')'  */
#line 371 "ldgram.y"
                { lang_ld_feature ((yyvsp[-1].name)); }
#line 2995 "ldgram.c"
    break;

  case 97: /* $@9: %empty  */
#line 375 "ldgram.y"
                { ldlex_inputlist(); }
#line 3001 "ldgram.c"
    break;

  case 98: /* input_list: $@9 input_list1  */
#line 377 "ldgram.y"
                { ldlex_popstate(); }
#line 3007 "ldgram.c"
    break;

  case 99: /* input_list1: NAME  */
#line 381 "ldgram.y"
                { lang_add_input_file ((yyvsp[0].name),
				       (input_flags.fake_archive
					? lang_input_file_is_search_member_enum
					: lang_input_file_is_search_file_enum),
				       (char *) NULL); }
#line 3017 "ldgram.c"
    break;

  case 100: /* input_list1: input_list1 ',' NAME  */
#line 387 "ldgram.y"
                { lang_add_input_file ((yyvsp[0].name),
				       (input_flags.fake_archive
					? lang_input_file_is_search_member_enum
					: lang_input_file_is_search_file_enum),
				       (char *) NULL); }
#line 3027 "ldgram.c"
    break;

  case 101: /* input_list1: input_list1 NAME  */
#line 393 "ldgram.y"
                { lang_add_input_file ((yyvsp[0].name),
				       (input_flags.fake_archive
					? lang_input_file_is_search_member_enum
					: lang_input_file_is_search_file_enum),
				       (char *) NULL); }
#line 3037 "ldgram.c"
    break;

  case 102: /* input_list1: LNAME  */
#line 399 "ldgram.y"
                { lang_add_input_file((yyvsp[0].name),lang_input_file_is_l_enum,
				 (char *)NULL); }
#line 3044 "ldgram.c"
    break;

  case 103: /* input_list1: input_list1 ',' LNAME  */
#line 402 "ldgram.y"
                { lang_add_input_file((yyvsp[0].name),lang_input_file_is_l_enum,
				 (char *)NULL); }
#line 3051 "ldgram.c"
    break;

  case 104: /* input_list1: input_list1 LNAME  */
#line 405 "ldgram.y"
                { lang_add_input_file((yyvsp[0].name),lang_input_file_is_l_enum,
				 (char *)NULL); }
#line 3058 "ldgram.c"
    break;

  case 105: /* @10: %empty  */
#line 408 "ldgram.y"
                  { (yyval.integer) = input_flags.add_DT_NEEDED_for_regular;
		    input_flags.add_DT_NEEDED_for_regular = true; }
#line 3065 "ldgram.c"
    break;

  case 106: /* input_list1: AS_NEEDED '(' @10 input_list1 ')'  */
#line 411 "ldgram.y"
                  { input_flags.add_DT_NEEDED_for_regular = (yyvsp[-2].integer); }
#line 3071 "ldgram.c"
    break;

  case 107: /* @11: %empty  */
#line 413 "ldgram.y"
                  { (yyval.integer) = input_flags.add_DT_NEEDED_for_regular;
		    input_flags.add_DT_NEEDED_for_regular = true; }
#line 3078 "ldgram.c"
    break;

  case 108: /* input_list1: input_list1 ',' AS_NEEDED '(' @11 input_list1 ')'  */
#line 416 "ldgram.y"
                  { input_flags.add_DT_NEEDED_for_regular = (yyvsp[-2].integer); }
#line 3084 "ldgram.c"
    break;

  case 109: /* @12: %empty  */
#line 418 "ldgram.y"
                  { (yyval.integer) = input_flags.add_DT_NEEDED_for_regular;
		    input_flags.add_DT_NEEDED_for_regular = true; }
#line 3091 "ldgram.c"
    break;

  case 110: /* input_list1: input_list1 AS_NEEDED '(' @12 input_list1 ')'  */
#line 421 "ldgram.y"
                  { input_flags.add_DT_NEEDED_for_regular = (yyvsp[-2].integer); }
#line 3097 "ldgram.c"
    break;

  case 115: /* statement_anywhere: ENTRY '(' NAME ')'  */
#line 436 "ldgram.y"
                { lang_add_entry ((yyvsp[-1].name), false); }
#line 3103 "ldgram.c"
    break;

  case 117: /* $@13: %empty  */
#line 438 "ldgram.y"
                          {ldlex_expression ();}
#line 3109 "ldgram.c"
    break;

  case 118: /* statement_anywhere: ASSERT_K $@13 '(' exp ',' NAME ')'  */
#line 439 "ldgram.y"
                { ldlex_popstate ();
		  lang_add_assignment (exp_assert ((yyvsp[-3].etree), (yyvsp[-1].name))); }
#line 3116 "ldgram.c"
    break;

  case 119: /* wildcard_name: NAME  */
#line 445 "ldgram.y"
                        {
			  (yyval.cname) = (yyvsp[0].name);
			}
#line 3124 "ldgram.c"
    break;

  case 120: /* wildcard_maybe_exclude: wildcard_name  */
#line 452 "ldgram.y"
                        {
			  (yyval.wildcard).name = (yyvsp[0].cname);
			  (yyval.wildcard).sorted = none;
			  (yyval.wildcard).exclude_name_list = NULL;
			  (yyval.wildcard).section_flag_list = NULL;
			  (yyval.wildcard).reversed = false;
			}
#line 3136 "ldgram.c"
    break;

  case 121: /* wildcard_maybe_exclude: EXCLUDE_FILE '(' exclude_name_list ')' wildcard_name  */
#line 460 "ldgram.y"
                        {
			  (yyval.wildcard).name = (yyvsp[0].cname);
			  (yyval.wildcard).sorted = none;
			  (yyval.wildcard).exclude_name_list = (yyvsp[-2].name_list);
			  (yyval.wildcard).section_flag_list = NULL;
			  (yyval.wildcard).reversed = false;
			}
#line 3148 "ldgram.c"
    break;

  case 123: /* wildcard_maybe_reverse: REVERSE '(' wildcard_maybe_exclude ')'  */
#line 472 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-1].wildcard);
			  (yyval.wildcard).reversed = true;
			  (yyval.wildcard).sorted = by_name;
			}
#line 3158 "ldgram.c"
    break;

  case 125: /* filename_spec: SORT_BY_NAME '(' wildcard_maybe_reverse ')'  */
#line 482 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-1].wildcard);
			  (yyval.wildcard).sorted = by_name;
			}
#line 3167 "ldgram.c"
    break;

  case 126: /* filename_spec: SORT_NONE '(' wildcard_maybe_reverse ')'  */
#line 487 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-1].wildcard);
			  (yyval.wildcard).sorted = by_none;
			  (yyval.wildcard).reversed = false;
			}
#line 3177 "ldgram.c"
    break;

  case 127: /* filename_spec: REVERSE '(' SORT_BY_NAME '(' wildcard_maybe_exclude ')' ')'  */
#line 493 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-2].wildcard);
			  (yyval.wildcard).sorted = by_name;
			  (yyval.wildcard).reversed = true;
			}
#line 3187 "ldgram.c"
    break;

  case 129: /* section_name_spec: SORT_BY_NAME '(' wildcard_maybe_reverse ')'  */
#line 503 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-1].wildcard);
			  (yyval.wildcard).sorted = by_name;
			}
#line 3196 "ldgram.c"
    break;

  case 130: /* section_name_spec: SORT_BY_ALIGNMENT '(' wildcard_maybe_reverse ')'  */
#line 508 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-1].wildcard);
			  (yyval.wildcard).sorted = by_alignment;
			}
#line 3205 "ldgram.c"
    break;

  case 131: /* section_name_spec: SORT_NONE '(' wildcard_maybe_reverse ')'  */
#line 513 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-1].wildcard);
			  (yyval.wildcard).sorted = by_none;
			}
#line 3214 "ldgram.c"
    break;

  case 132: /* section_name_spec: SORT_BY_NAME '(' SORT_BY_ALIGNMENT '(' wildcard_maybe_reverse ')' ')'  */
#line 518 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-2].wildcard);
			  (yyval.wildcard).sorted = by_name_alignment;
			}
#line 3223 "ldgram.c"
    break;

  case 133: /* section_name_spec: SORT_BY_NAME '(' SORT_BY_NAME '(' wildcard_maybe_reverse ')' ')'  */
#line 523 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-2].wildcard);
			  (yyval.wildcard).sorted = by_name;
			}
#line 3232 "ldgram.c"
    break;

  case 134: /* section_name_spec: SORT_BY_ALIGNMENT '(' SORT_BY_NAME '(' wildcard_maybe_reverse ')' ')'  */
#line 528 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-2].wildcard);
			  (yyval.wildcard).sorted = by_alignment_name;
			}
#line 3241 "ldgram.c"
    break;

  case 135: /* section_name_spec: SORT_BY_ALIGNMENT '(' SORT_BY_ALIGNMENT '(' wildcard_maybe_reverse ')' ')'  */
#line 533 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-2].wildcard);
			  (yyval.wildcard).sorted = by_alignment;
			}
#line 3250 "ldgram.c"
    break;

  case 136: /* section_name_spec: SORT_BY_INIT_PRIORITY '(' wildcard_maybe_reverse ')'  */
#line 538 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-1].wildcard);
			  (yyval.wildcard).sorted = by_init_priority;
			}
#line 3259 "ldgram.c"
    break;

  case 137: /* section_name_spec: REVERSE '(' SORT_BY_NAME '(' wildcard_maybe_exclude ')' ')'  */
#line 543 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-2].wildcard);
			  (yyval.wildcard).sorted = by_name;
			  (yyval.wildcard).reversed = true;
			}
#line 3269 "ldgram.c"
    break;

  case 138: /* section_name_spec: REVERSE '(' SORT_BY_INIT_PRIORITY '(' wildcard_maybe_exclude ')' ')'  */
#line 549 "ldgram.y"
                        {
			  (yyval.wildcard) = (yyvsp[-2].wildcard);
			  (yyval.wildcard).sorted = by_init_priority;
			  (yyval.wildcard).reversed = true;
			}
#line 3279 "ldgram.c"
    break;

  case 139: /* sect_flag_list: NAME  */
#line 557 "ldgram.y"
                        {
			  struct flag_info_list *n;
			  n = stat_alloc (sizeof *n);
			  if ((yyvsp[0].name)[0] == '!')
			    {
			      n->with = without_flags;
			      n->name = &(yyvsp[0].name)[1];
			    }
			  else
			    {
			      n->with = with_flags;
			      n->name = (yyvsp[0].name);
			    }
			  n->valid = false;
			  n->next = NULL;
			  (yyval.flag_info_list) = n;
			}
#line 3301 "ldgram.c"
    break;

  case 140: /* sect_flag_list: sect_flag_list '&' NAME  */
#line 575 "ldgram.y"
                        {
			  struct flag_info_list *n;
			  n = stat_alloc (sizeof *n);
			  if ((yyvsp[0].name)[0] == '!')
			    {
			      n->with = without_flags;
			      n->name = &(yyvsp[0].name)[1];
			    }
			  else
			    {
			      n->with = with_flags;
			      n->name = (yyvsp[0].name);
			    }
			  n->valid = false;
			  n->next = (yyvsp[-2].flag_info_list);
			  (yyval.flag_info_list) = n;
			}
#line 3323 "ldgram.c"
    break;

  case 141: /* sect_flags: INPUT_SECTION_FLAGS '(' sect_flag_list ')'  */
#line 596 "ldgram.y"
                        {
			  struct flag_info *n;
			  n = stat_alloc (sizeof *n);
			  n->flag_list = (yyvsp[-1].flag_info_list);
			  n->flags_initialized = false;
			  n->not_with_flags = 0;
			  n->only_with_flags = 0;
			  (yyval.flag_info) = n;
			}
#line 3337 "ldgram.c"
    break;

  case 142: /* exclude_name_list: exclude_name_list wildcard_name  */
#line 609 "ldgram.y"
                        {
			  struct name_list *tmp;
			  tmp = stat_alloc (sizeof *tmp);
			  tmp->name = (yyvsp[0].cname);
			  tmp->next = (yyvsp[-1].name_list);
			  (yyval.name_list) = tmp;
			}
#line 3349 "ldgram.c"
    break;

  case 143: /* exclude_name_list: wildcard_name  */
#line 618 "ldgram.y"
                        {
			  struct name_list *tmp;
			  tmp = stat_alloc (sizeof *tmp);
			  tmp->name = (yyvsp[0].cname);
			  tmp->next = NULL;
			  (yyval.name_list) = tmp;
			}
#line 3361 "ldgram.c"
    break;

  case 144: /* section_name_list: section_name_list opt_comma section_name_spec  */
#line 629 "ldgram.y"
                        {
			  struct wildcard_list *tmp;
			  tmp = stat_alloc (sizeof *tmp);
			  tmp->next = (yyvsp[-2].wildcard_list);
			  tmp->spec = (yyvsp[0].wildcard);
			  (yyval.wildcard_list) = tmp;
			}
#line 3373 "ldgram.c"
    break;

  case 145: /* section_name_list: section_name_spec  */
#line 638 "ldgram.y"
                        {
			  struct wildcard_list *tmp;
			  tmp = stat_alloc (sizeof *tmp);
			  tmp->next = NULL;
			  tmp->spec = (yyvsp[0].wildcard);
			  (yyval.wildcard_list) = tmp;
			}
#line 3385 "ldgram.c"
    break;

  case 146: /* input_section_spec_no_keep: NAME  */
#line 649 "ldgram.y"
                        {
			  struct wildcard_spec tmp;
			  tmp.name = (yyvsp[0].name);
			  tmp.exclude_name_list = NULL;
			  tmp.sorted = none;
			  tmp.section_flag_list = NULL;
			  lang_add_wild (&tmp, NULL, ldgram_had_keep);
			}
#line 3398 "ldgram.c"
    break;

  case 147: /* input_section_spec_no_keep: sect_flags NAME  */
#line 658 "ldgram.y"
                        {
			  struct wildcard_spec tmp;
			  tmp.name = (yyvsp[0].name);
			  tmp.exclude_name_list = NULL;
			  tmp.sorted = none;
			  tmp.section_flag_list = (yyvsp[-1].flag_info);
			  lang_add_wild (&tmp, NULL, ldgram_had_keep);
			}
#line 3411 "ldgram.c"
    break;

  case 148: /* input_section_spec_no_keep: '[' section_name_list ']'  */
#line 667 "ldgram.y"
                        {
			  lang_add_wild (NULL, (yyvsp[-1].wildcard_list), ldgram_had_keep);
			}
#line 3419 "ldgram.c"
    break;

  case 149: /* input_section_spec_no_keep: sect_flags '[' section_name_list ']'  */
#line 671 "ldgram.y"
                        {
			  struct wildcard_spec tmp;
			  tmp.name = NULL;
			  tmp.exclude_name_list = NULL;
			  tmp.sorted = none;
			  tmp.section_flag_list = (yyvsp[-3].flag_info);
			  lang_add_wild (&tmp, (yyvsp[-1].wildcard_list), ldgram_had_keep);
			}
#line 3432 "ldgram.c"
    break;

  case 150: /* input_section_spec_no_keep: filename_spec '(' section_name_list ')'  */
#line 680 "ldgram.y"
                        {
			  lang_add_wild (&(yyvsp[-3].wildcard), (yyvsp[-1].wildcard_list), ldgram_had_keep);
			}
#line 3440 "ldgram.c"
    break;

  case 151: /* input_section_spec_no_keep: sect_flags filename_spec '(' section_name_list ')'  */
#line 684 "ldgram.y"
                        {
			  (yyvsp[-3].wildcard).section_flag_list = (yyvsp[-4].flag_info);
			  lang_add_wild (&(yyvsp[-3].wildcard), (yyvsp[-1].wildcard_list), ldgram_had_keep);
			}
#line 3449 "ldgram.c"
    break;

  case 153: /* $@14: %empty  */
#line 693 "ldgram.y"
                        { ldgram_had_keep = true; }
#line 3455 "ldgram.c"
    break;

  case 154: /* input_section_spec: KEEP '(' $@14 input_section_spec_no_keep ')'  */
#line 695 "ldgram.y"
                        { ldgram_had_keep = false; }
#line 3461 "ldgram.c"
    break;

  case 157: /* statement: CREATE_OBJECT_SYMBOLS  */
#line 702 "ldgram.y"
                {
		  lang_add_attribute (lang_object_symbols_statement_enum);
		}
#line 3469 "ldgram.c"
    break;

  case 158: /* statement: CONSTRUCTORS  */
#line 706 "ldgram.y"
                {
		  lang_add_attribute (lang_constructors_statement_enum);
		}
#line 3477 "ldgram.c"
    break;

  case 159: /* statement: SORT_BY_NAME '(' CONSTRUCTORS ')'  */
#line 710 "ldgram.y"
                {
		  constructors_sorted = true;
		  lang_add_attribute (lang_constructors_statement_enum);
		}
#line 3486 "ldgram.c"
    break;

  case 161: /* statement: length '(' mustbe_exp ')'  */
#line 716 "ldgram.y"
                {
		  lang_add_data ((int) (yyvsp[-3].integer), (yyvsp[-1].etree));
		}
#line 3494 "ldgram.c"
    break;

  case 162: /* statement: ASCIZ NAME  */
#line 720 "ldgram.y"
                {
		  lang_add_string ((yyvsp[0].name));
		}
#line 3502 "ldgram.c"
    break;

  case 163: /* statement: FILL '(' fill_exp ')'  */
#line 724 "ldgram.y"
                {
		  lang_add_fill ((yyvsp[-1].fill));
		}
#line 3510 "ldgram.c"
    break;

  case 164: /* statement: LINKER_VERSION  */
#line 728 "ldgram.y"
                {
		  lang_add_version_string ();
		}
#line 3518 "ldgram.c"
    break;

  case 165: /* $@15: %empty  */
#line 732 "ldgram.y"
                { ldlex_expression (); }
#line 3524 "ldgram.c"
    break;

  case 166: /* statement: ASSERT_K $@15 '(' exp ',' NAME ')' separator  */
#line 734 "ldgram.y"
                {
		  ldlex_popstate ();
		  lang_add_assignment (exp_assert ((yyvsp[-4].etree), (yyvsp[-2].name)));
		}
#line 3533 "ldgram.c"
    break;

  case 167: /* $@16: %empty  */
#line 739 "ldgram.y"
                {
		  ldfile_open_command_file ((yyvsp[0].name));
		}
#line 3541 "ldgram.c"
    break;

  case 173: /* length: QUAD  */
#line 757 "ldgram.y"
                        { (yyval.integer) = (yyvsp[0].token); }
#line 3547 "ldgram.c"
    break;

  case 174: /* length: SQUAD  */
#line 759 "ldgram.y"
                        { (yyval.integer) = (yyvsp[0].token); }
#line 3553 "ldgram.c"
    break;

  case 175: /* length: LONG  */
#line 761 "ldgram.y"
                        { (yyval.integer) = (yyvsp[0].token); }
#line 3559 "ldgram.c"
    break;

  case 176: /* length: SHORT  */
#line 763 "ldgram.y"
                        { (yyval.integer) = (yyvsp[0].token); }
#line 3565 "ldgram.c"
    break;

  case 177: /* length: BYTE  */
#line 765 "ldgram.y"
                        { (yyval.integer) = (yyvsp[0].token); }
#line 3571 "ldgram.c"
    break;

  case 178: /* fill_exp: mustbe_exp  */
#line 770 "ldgram.y"
                {
		  (yyval.fill) = exp_get_fill ((yyvsp[0].etree), 0, _("fill value"));
		}
#line 3579 "ldgram.c"
    break;

  case 179: /* fill_opt: '=' fill_exp  */
#line 777 "ldgram.y"
                { (yyval.fill) = (yyvsp[0].fill); }
#line 3585 "ldgram.c"
    break;

  case 180: /* fill_opt: %empty  */
#line 778 "ldgram.y"
                { (yyval.fill) = (fill_type *) 0; }
#line 3591 "ldgram.c"
    break;

  case 181: /* assign_op: PLUSEQ  */
#line 783 "ldgram.y"
                        { (yyval.token) = '+'; }
#line 3597 "ldgram.c"
    break;

  case 182: /* assign_op: MINUSEQ  */
#line 785 "ldgram.y"
                        { (yyval.token) = '-'; }
#line 3603 "ldgram.c"
    break;

  case 183: /* assign_op: MULTEQ  */
#line 787 "ldgram.y"
                        { (yyval.token) = '*'; }
#line 3609 "ldgram.c"
    break;

  case 184: /* assign_op: DIVEQ  */
#line 789 "ldgram.y"
                        { (yyval.token) = '/'; }
#line 3615 "ldgram.c"
    break;

  case 185: /* assign_op: LSHIFTEQ  */
#line 791 "ldgram.y"
                        { (yyval.token) = LSHIFT; }
#line 3621 "ldgram.c"
    break;

  case 186: /* assign_op: RSHIFTEQ  */
#line 793 "ldgram.y"
                        { (yyval.token) = RSHIFT; }
#line 3627 "ldgram.c"
    break;

  case 187: /* assign_op: ANDEQ  */
#line 795 "ldgram.y"
                        { (yyval.token) = '&'; }
#line 3633 "ldgram.c"
    break;

  case 188: /* assign_op: OREQ  */
#line 797 "ldgram.y"
                        { (yyval.token) = '|'; }
#line 3639 "ldgram.c"
    break;

  case 189: /* assign_op: XOREQ  */
#line 799 "ldgram.y"
                        { (yyval.token) = '^'; }
#line 3645 "ldgram.c"
    break;

  case 192: /* assignment: NAME '=' mustbe_exp  */
#line 809 "ldgram.y"
                {
		  lang_add_assignment (exp_assign ((yyvsp[-2].name), (yyvsp[0].etree), false));
		}
#line 3653 "ldgram.c"
    break;

  case 193: /* assignment: NAME assign_op mustbe_exp  */
#line 813 "ldgram.y"
                {
		  lang_add_assignment (exp_assign ((yyvsp[-2].name),
						   exp_binop ((yyvsp[-1].token),
							      exp_nameop (NAME,
									  (yyvsp[-2].name)),
							      (yyvsp[0].etree)), false));
		}
#line 3665 "ldgram.c"
    break;

  case 194: /* assignment: HIDDEN '(' NAME '=' mustbe_exp ')'  */
#line 821 "ldgram.y"
                {
		  lang_add_assignment (exp_assign ((yyvsp[-3].name), (yyvsp[-1].etree), true));
		}
#line 3673 "ldgram.c"
    break;

  case 195: /* assignment: PROVIDE '(' NAME '=' mustbe_exp ')'  */
#line 825 "ldgram.y"
                {
		  lang_add_assignment (exp_provide ((yyvsp[-3].name), (yyvsp[-1].etree), false));
		}
#line 3681 "ldgram.c"
    break;

  case 196: /* assignment: PROVIDE_HIDDEN '(' NAME '=' mustbe_exp ')'  */
#line 829 "ldgram.y"
                {
		  lang_add_assignment (exp_provide ((yyvsp[-3].name), (yyvsp[-1].etree), true));
		}
#line 3689 "ldgram.c"
    break;

  case 204: /* $@17: %empty  */
#line 852 "ldgram.y"
                { region = lang_memory_region_lookup ((yyvsp[0].name), true); }
#line 3695 "ldgram.c"
    break;

  case 205: /* memory_spec: NAME $@17 attributes_opt ':' origin_spec opt_comma length_spec  */
#line 855 "ldgram.y"
                {}
#line 3701 "ldgram.c"
    break;

  case 206: /* $@18: %empty  */
#line 857 "ldgram.y"
                { ldfile_open_command_file ((yyvsp[0].name)); }
#line 3707 "ldgram.c"
    break;

  case 208: /* origin_spec: ORIGIN '=' mustbe_exp  */
#line 863 "ldgram.y"
                {
		  region->origin_exp = (yyvsp[0].etree);
		}
#line 3715 "ldgram.c"
    break;

  case 209: /* length_spec: LENGTH '=' mustbe_exp  */
#line 870 "ldgram.y"
                {
		  if (yychar == NAME)
		    {
		      yyclearin;
		      ldlex_backup ();
		    }
		  region->length_exp = (yyvsp[0].etree);
		}
#line 3728 "ldgram.c"
    break;

  case 210: /* attributes_opt: %empty  */
#line 882 "ldgram.y"
                  { /* dummy action to avoid bison 1.25 error message */ }
#line 3734 "ldgram.c"
    break;

  case 214: /* attributes_string: NAME  */
#line 893 "ldgram.y"
                  { lang_set_flags (region, (yyvsp[0].name), 0); }
#line 3740 "ldgram.c"
    break;

  case 215: /* attributes_string: '!' NAME  */
#line 895 "ldgram.y"
                  { lang_set_flags (region, (yyvsp[0].name), 1); }
#line 3746 "ldgram.c"
    break;

  case 216: /* startup: STARTUP '(' filename ')'  */
#line 900 "ldgram.y"
                { lang_startup((yyvsp[-1].name)); }
#line 3752 "ldgram.c"
    break;

  case 218: /* high_level_library: HLL '(' ')'  */
#line 906 "ldgram.y"
                        { ldemul_hll((char *)NULL); }
#line 3758 "ldgram.c"
    break;

  case 219: /* high_level_library_NAME_list: high_level_library_NAME_list opt_comma filename  */
#line 911 "ldgram.y"
                        { ldemul_hll((yyvsp[0].name)); }
#line 3764 "ldgram.c"
    break;

  case 220: /* high_level_library_NAME_list: filename  */
#line 913 "ldgram.y"
                        { ldemul_hll((yyvsp[0].name)); }
#line 3770 "ldgram.c"
    break;

  case 222: /* low_level_library_NAME_list: low_level_library_NAME_list opt_comma filename  */
#line 922 "ldgram.y"
                        { ldemul_syslib((yyvsp[0].name)); }
#line 3776 "ldgram.c"
    break;

  case 224: /* floating_point_support: FLOAT  */
#line 928 "ldgram.y"
                        { lang_float(true); }
#line 3782 "ldgram.c"
    break;

  case 225: /* floating_point_support: NOFLOAT  */
#line 930 "ldgram.y"
                        { lang_float(false); }
#line 3788 "ldgram.c"
    break;

  case 226: /* nocrossref_list: %empty  */
#line 935 "ldgram.y"
                {
		  (yyval.nocrossref) = NULL;
		}
#line 3796 "ldgram.c"
    break;

  case 227: /* nocrossref_list: NAME nocrossref_list  */
#line 939 "ldgram.y"
                {
		  struct lang_nocrossref *n;

		  n = stat_alloc (sizeof *n);
		  n->name = (yyvsp[-1].name);
		  n->next = (yyvsp[0].nocrossref);
		  (yyval.nocrossref) = n;
		}
#line 3809 "ldgram.c"
    break;

  case 228: /* nocrossref_list: NAME ',' nocrossref_list  */
#line 948 "ldgram.y"
                {
		  struct lang_nocrossref *n;

		  n = stat_alloc (sizeof *n);
		  n->name = (yyvsp[-2].name);
		  n->next = (yyvsp[0].nocrossref);
		  (yyval.nocrossref) = n;
		}
#line 3822 "ldgram.c"
    break;

  case 229: /* $@19: %empty  */
#line 958 "ldgram.y"
                        { ldlex_script (); }
#line 3828 "ldgram.c"
    break;

  case 230: /* paren_script_name: $@19 '(' NAME ')'  */
#line 960 "ldgram.y"
                        { ldlex_popstate (); (yyval.name) = (yyvsp[-1].name); }
#line 3834 "ldgram.c"
    break;

  case 231: /* $@20: %empty  */
#line 962 "ldgram.y"
                        { ldlex_expression (); }
#line 3840 "ldgram.c"
    break;

  case 232: /* mustbe_exp: $@20 exp  */
#line 964 "ldgram.y"
                        { ldlex_popstate (); (yyval.etree) = (yyvsp[0].etree); }
#line 3846 "ldgram.c"
    break;

  case 233: /* exp: '-' exp  */
#line 969 "ldgram.y"
                        { (yyval.etree) = exp_unop ('-', (yyvsp[0].etree)); }
#line 3852 "ldgram.c"
    break;

  case 234: /* exp: '(' exp ')'  */
#line 971 "ldgram.y"
                        { (yyval.etree) = (yyvsp[-1].etree); }
#line 3858 "ldgram.c"
    break;

  case 235: /* exp: NEXT '(' exp ')'  */
#line 973 "ldgram.y"
                        { (yyval.etree) = exp_unop ((int) (yyvsp[-3].integer),(yyvsp[-1].etree)); }
#line 3864 "ldgram.c"
    break;

  case 236: /* exp: '!' exp  */
#line 975 "ldgram.y"
                        { (yyval.etree) = exp_unop ('!', (yyvsp[0].etree)); }
#line 3870 "ldgram.c"
    break;

  case 237: /* exp: '+' exp  */
#line 977 "ldgram.y"
                        { (yyval.etree) = (yyvsp[0].etree); }
#line 3876 "ldgram.c"
    break;

  case 238: /* exp: '~' exp  */
#line 979 "ldgram.y"
                        { (yyval.etree) = exp_unop ('~', (yyvsp[0].etree));}
#line 3882 "ldgram.c"
    break;

  case 239: /* exp: exp '*' exp  */
#line 982 "ldgram.y"
                        { (yyval.etree) = exp_binop ('*', (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3888 "ldgram.c"
    break;

  case 240: /* exp: exp '/' exp  */
#line 984 "ldgram.y"
                        { (yyval.etree) = exp_binop ('/', (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3894 "ldgram.c"
    break;

  case 241: /* exp: exp '%' exp  */
#line 986 "ldgram.y"
                        { (yyval.etree) = exp_binop ('%', (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3900 "ldgram.c"
    break;

  case 242: /* exp: exp '+' exp  */
#line 988 "ldgram.y"
                        { (yyval.etree) = exp_binop ('+', (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3906 "ldgram.c"
    break;

  case 243: /* exp: exp '-' exp  */
#line 990 "ldgram.y"
                        { (yyval.etree) = exp_binop ('-' , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3912 "ldgram.c"
    break;

  case 244: /* exp: exp LSHIFT exp  */
#line 992 "ldgram.y"
                        { (yyval.etree) = exp_binop (LSHIFT , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3918 "ldgram.c"
    break;

  case 245: /* exp: exp RSHIFT exp  */
#line 994 "ldgram.y"
                        { (yyval.etree) = exp_binop (RSHIFT , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3924 "ldgram.c"
    break;

  case 246: /* exp: exp EQ exp  */
#line 996 "ldgram.y"
                        { (yyval.etree) = exp_binop (EQ , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3930 "ldgram.c"
    break;

  case 247: /* exp: exp NE exp  */
#line 998 "ldgram.y"
                        { (yyval.etree) = exp_binop (NE , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3936 "ldgram.c"
    break;

  case 248: /* exp: exp LE exp  */
#line 1000 "ldgram.y"
                        { (yyval.etree) = exp_binop (LE , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3942 "ldgram.c"
    break;

  case 249: /* exp: exp GE exp  */
#line 1002 "ldgram.y"
                        { (yyval.etree) = exp_binop (GE , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3948 "ldgram.c"
    break;

  case 250: /* exp: exp '<' exp  */
#line 1004 "ldgram.y"
                        { (yyval.etree) = exp_binop ('<' , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3954 "ldgram.c"
    break;

  case 251: /* exp: exp '>' exp  */
#line 1006 "ldgram.y"
                        { (yyval.etree) = exp_binop ('>' , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3960 "ldgram.c"
    break;

  case 252: /* exp: exp '&' exp  */
#line 1008 "ldgram.y"
                        { (yyval.etree) = exp_binop ('&' , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3966 "ldgram.c"
    break;

  case 253: /* exp: exp '^' exp  */
#line 1010 "ldgram.y"
                        { (yyval.etree) = exp_binop ('^' , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3972 "ldgram.c"
    break;

  case 254: /* exp: exp '|' exp  */
#line 1012 "ldgram.y"
                        { (yyval.etree) = exp_binop ('|' , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3978 "ldgram.c"
    break;

  case 255: /* exp: exp '?' exp ':' exp  */
#line 1014 "ldgram.y"
                        { (yyval.etree) = exp_trinop ('?' , (yyvsp[-4].etree), (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3984 "ldgram.c"
    break;

  case 256: /* exp: exp ANDAND exp  */
#line 1016 "ldgram.y"
                        { (yyval.etree) = exp_binop (ANDAND , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3990 "ldgram.c"
    break;

  case 257: /* exp: exp OROR exp  */
#line 1018 "ldgram.y"
                        { (yyval.etree) = exp_binop (OROR , (yyvsp[-2].etree), (yyvsp[0].etree)); }
#line 3996 "ldgram.c"
    break;

  case 258: /* exp: DEFINED '(' NAME ')'  */
#line 1020 "ldgram.y"
                        { (yyval.etree) = exp_nameop (DEFINED, (yyvsp[-1].name)); }
#line 4002 "ldgram.c"
    break;

  case 259: /* exp: INT  */
#line 1022 "ldgram.y"
                        { (yyval.etree) = exp_bigintop ((yyvsp[0].bigint).integer, (yyvsp[0].bigint).str); }
#line 4008 "ldgram.c"
    break;

  case 260: /* exp: SIZEOF_HEADERS  */
#line 1024 "ldgram.y"
                        { (yyval.etree) = exp_nameop (SIZEOF_HEADERS,0); }
#line 4014 "ldgram.c"
    break;

  case 261: /* exp: ALIGNOF paren_script_name  */
#line 1027 "ldgram.y"
                        { (yyval.etree) = exp_nameop (ALIGNOF, (yyvsp[0].name)); }
#line 4020 "ldgram.c"
    break;

  case 262: /* exp: SIZEOF paren_script_name  */
#line 1029 "ldgram.y"
                        { (yyval.etree) = exp_nameop (SIZEOF, (yyvsp[0].name)); }
#line 4026 "ldgram.c"
    break;

  case 263: /* exp: ADDR paren_script_name  */
#line 1031 "ldgram.y"
                        { (yyval.etree) = exp_nameop (ADDR, (yyvsp[0].name)); }
#line 4032 "ldgram.c"
    break;

  case 264: /* exp: LOADADDR paren_script_name  */
#line 1033 "ldgram.y"
                        { (yyval.etree) = exp_nameop (LOADADDR, (yyvsp[0].name)); }
#line 4038 "ldgram.c"
    break;

  case 265: /* exp: CONSTANT '(' NAME ')'  */
#line 1035 "ldgram.y"
                        { (yyval.etree) = exp_nameop (CONSTANT,(yyvsp[-1].name)); }
#line 4044 "ldgram.c"
    break;

  case 266: /* exp: ABSOLUTE '(' exp ')'  */
#line 1037 "ldgram.y"
                        { (yyval.etree) = exp_unop (ABSOLUTE, (yyvsp[-1].etree)); }
#line 4050 "ldgram.c"
    break;

  case 267: /* exp: ALIGN_K '(' exp ')'  */
#line 1039 "ldgram.y"
                        { (yyval.etree) = exp_unop (ALIGN_K,(yyvsp[-1].etree)); }
#line 4056 "ldgram.c"
    break;

  case 268: /* exp: ALIGN_K '(' exp ',' exp ')'  */
#line 1041 "ldgram.y"
                        { (yyval.etree) = exp_binop (ALIGN_K,(yyvsp[-3].etree),(yyvsp[-1].etree)); }
#line 4062 "ldgram.c"
    break;

  case 269: /* exp: DATA_SEGMENT_ALIGN '(' exp ',' exp ')'  */
#line 1043 "ldgram.y"
                        { (yyval.etree) = exp_binop (DATA_SEGMENT_ALIGN, (yyvsp[-3].etree), (yyvsp[-1].etree)); }
#line 4068 "ldgram.c"
    break;

  case 270: /* exp: DATA_SEGMENT_RELRO_END '(' exp ',' exp ')'  */
#line 1045 "ldgram.y"
                        { (yyval.etree) = exp_binop (DATA_SEGMENT_RELRO_END, (yyvsp[-1].etree), (yyvsp[-3].etree)); }
#line 4074 "ldgram.c"
    break;

  case 271: /* exp: DATA_SEGMENT_END '(' exp ')'  */
#line 1047 "ldgram.y"
                        { (yyval.etree) = exp_unop (DATA_SEGMENT_END, (yyvsp[-1].etree)); }
#line 4080 "ldgram.c"
    break;

  case 272: /* $@21: %empty  */
#line 1048 "ldgram.y"
                              { ldlex_script (); }
#line 4086 "ldgram.c"
    break;

  case 273: /* $@22: %empty  */
#line 1049 "ldgram.y"
                        { ldlex_popstate (); }
#line 4092 "ldgram.c"
    break;

  case 274: /* exp: SEGMENT_START $@21 '(' NAME $@22 ',' exp ')'  */
#line 1050 "ldgram.y"
                        { /* The operands to the expression node are
			     placed in the opposite order from the way
			     in which they appear in the script as
			     that allows us to reuse more code in
			     fold_binary.  */
			  (yyval.etree) = exp_binop (SEGMENT_START,
					  (yyvsp[-1].etree),
					  exp_nameop (NAME, (yyvsp[-4].name))); }
#line 4105 "ldgram.c"
    break;

  case 275: /* exp: BLOCK '(' exp ')'  */
#line 1059 "ldgram.y"
                        { (yyval.etree) = exp_unop (ALIGN_K,(yyvsp[-1].etree)); }
#line 4111 "ldgram.c"
    break;

  case 276: /* exp: NAME  */
#line 1061 "ldgram.y"
                        { (yyval.etree) = exp_nameop (NAME,(yyvsp[0].name)); }
#line 4117 "ldgram.c"
    break;

  case 277: /* exp: MAX_K '(' exp ',' exp ')'  */
#line 1063 "ldgram.y"
                        { (yyval.etree) = exp_binop (MAX_K, (yyvsp[-3].etree), (yyvsp[-1].etree) ); }
#line 4123 "ldgram.c"
    break;

  case 278: /* exp: MIN_K '(' exp ',' exp ')'  */
#line 1065 "ldgram.y"
                        { (yyval.etree) = exp_binop (MIN_K, (yyvsp[-3].etree), (yyvsp[-1].etree) ); }
#line 4129 "ldgram.c"
    break;

  case 279: /* exp: ASSERT_K '(' exp ',' NAME ')'  */
#line 1067 "ldgram.y"
                        { (yyval.etree) = exp_assert ((yyvsp[-3].etree), (yyvsp[-1].name)); }
#line 4135 "ldgram.c"
    break;

  case 280: /* exp: ORIGIN paren_script_name  */
#line 1069 "ldgram.y"
                        { (yyval.etree) = exp_nameop (ORIGIN, (yyvsp[0].name)); }
#line 4141 "ldgram.c"
    break;

  case 281: /* exp: LENGTH paren_script_name  */
#line 1071 "ldgram.y"
                        { (yyval.etree) = exp_nameop (LENGTH, (yyvsp[0].name)); }
#line 4147 "ldgram.c"
    break;

  case 282: /* exp: LOG2CEIL '(' exp ')'  */
#line 1073 "ldgram.y"
                        { (yyval.etree) = exp_unop (LOG2CEIL, (yyvsp[-1].etree)); }
#line 4153 "ldgram.c"
    break;

  case 283: /* memspec_at_opt: AT '>' NAME  */
#line 1078 "ldgram.y"
                            { (yyval.name) = (yyvsp[0].name); }
#line 4159 "ldgram.c"
    break;

  case 284: /* memspec_at_opt: %empty  */
#line 1079 "ldgram.y"
                { (yyval.name) = 0; }
#line 4165 "ldgram.c"
    break;

  case 285: /* opt_at: AT '(' exp ')'  */
#line 1083 "ldgram.y"
                               { (yyval.etree) = (yyvsp[-1].etree); }
#line 4171 "ldgram.c"
    break;

  case 286: /* opt_at: %empty  */
#line 1084 "ldgram.y"
                { (yyval.etree) = 0; }
#line 4177 "ldgram.c"
    break;

  case 287: /* opt_align: ALIGN_K '(' exp ')'  */
#line 1088 "ldgram.y"
                                    { (yyval.etree) = (yyvsp[-1].etree); }
#line 4183 "ldgram.c"
    break;

  case 288: /* opt_align: %empty  */
#line 1089 "ldgram.y"
                { (yyval.etree) = 0; }
#line 4189 "ldgram.c"
    break;

  case 289: /* opt_align_with_input: ALIGN_WITH_INPUT  */
#line 1093 "ldgram.y"
                                 { (yyval.token) = ALIGN_WITH_INPUT; }
#line 4195 "ldgram.c"
    break;

  case 290: /* opt_align_with_input: %empty  */
#line 1094 "ldgram.y"
                { (yyval.token) = 0; }
#line 4201 "ldgram.c"
    break;

  case 291: /* opt_subalign: SUBALIGN '(' exp ')'  */
#line 1098 "ldgram.y"
                                     { (yyval.etree) = (yyvsp[-1].etree); }
#line 4207 "ldgram.c"
    break;

  case 292: /* opt_subalign: %empty  */
#line 1099 "ldgram.y"
                { (yyval.etree) = 0; }
#line 4213 "ldgram.c"
    break;

  case 293: /* sect_constraint: ONLY_IF_RO  */
#line 1103 "ldgram.y"
                           { (yyval.token) = ONLY_IF_RO; }
#line 4219 "ldgram.c"
    break;

  case 294: /* sect_constraint: ONLY_IF_RW  */
#line 1104 "ldgram.y"
                           { (yyval.token) = ONLY_IF_RW; }
#line 4225 "ldgram.c"
    break;

  case 295: /* sect_constraint: SPECIAL  */
#line 1105 "ldgram.y"
                        { (yyval.token) = SPECIAL; }
#line 4231 "ldgram.c"
    break;

  case 296: /* sect_constraint: %empty  */
#line 1106 "ldgram.y"
                { (yyval.token) = 0; }
#line 4237 "ldgram.c"
    break;

  case 297: /* $@23: %empty  */
#line 1110 "ldgram.y"
                        { ldlex_expression(); }
#line 4243 "ldgram.c"
    break;

  case 298: /* $@24: %empty  */
#line 1117 "ldgram.y"
                        {
			  ldlex_popstate ();
			  ldlex_wild ();
			  lang_enter_output_section_statement ((yyvsp[-7].name), (yyvsp[-5].etree), sectype,
					sectype_value, (yyvsp[-3].etree), (yyvsp[-1].etree), (yyvsp[-4].etree), (yyvsp[0].token), (yyvsp[-2].token));
			}
#line 4254 "ldgram.c"
    break;

  case 299: /* $@25: %empty  */
#line 1126 "ldgram.y"
                        { ldlex_popstate (); }
#line 4260 "ldgram.c"
    break;

  case 300: /* $@26: %empty  */
#line 1128 "ldgram.y"
                        {
			  /* fill_opt may have switched the lexer into
			     expression state, and back again, but in
			     order to find the end of the fill
			     expression the parser must look ahead one
			     token.  If it is a NAME, throw it away as
			     it will have been lexed in the wrong
			     state.  */
			  if (yychar == NAME)
			    {
			      yyclearin;
			      ldlex_backup ();
			    }
			  lang_leave_output_section_statement ((yyvsp[0].fill), (yyvsp[-3].name),
							       (yyvsp[-1].section_phdr), (yyvsp[-2].name));
			}
#line 4281 "ldgram.c"
    break;

  case 302: /* $@27: %empty  */
#line 1146 "ldgram.y"
                        { ldlex_expression (); }
#line 4287 "ldgram.c"
    break;

  case 303: /* $@28: %empty  */
#line 1148 "ldgram.y"
                        { ldlex_popstate (); }
#line 4293 "ldgram.c"
    break;

  case 304: /* $@29: %empty  */
#line 1150 "ldgram.y"
                        {
			  lang_enter_overlay ((yyvsp[-5].etree), (yyvsp[-2].etree));
			}
#line 4301 "ldgram.c"
    break;

  case 305: /* $@30: %empty  */
#line 1156 "ldgram.y"
                        {
			  if (yychar == NAME)
			    {
			      yyclearin;
			      ldlex_backup ();
			    }
			  lang_leave_overlay ((yyvsp[-10].etree), (int) (yyvsp[-11].integer),
					      (yyvsp[0].fill), (yyvsp[-3].name), (yyvsp[-1].section_phdr), (yyvsp[-2].name));
			}
#line 4315 "ldgram.c"
    break;

  case 307: /* $@31: %empty  */
#line 1171 "ldgram.y"
                        { ldlex_expression (); }
#line 4321 "ldgram.c"
    break;

  case 308: /* $@32: %empty  */
#line 1173 "ldgram.y"
                        {
			  ldlex_popstate ();
			  lang_add_assignment (exp_assign (".", (yyvsp[0].etree), false));
			}
#line 4330 "ldgram.c"
    break;

  case 310: /* $@33: %empty  */
#line 1179 "ldgram.y"
                        {
			  ldfile_open_command_file ((yyvsp[0].name));
			}
#line 4338 "ldgram.c"
    break;

  case 312: /* type: NOLOAD  */
#line 1186 "ldgram.y"
                   { sectype = noload_section; }
#line 4344 "ldgram.c"
    break;

  case 313: /* type: DSECT  */
#line 1187 "ldgram.y"
                   { sectype = noalloc_section; }
#line 4350 "ldgram.c"
    break;

  case 314: /* type: COPY  */
#line 1188 "ldgram.y"
                   { sectype = noalloc_section; }
#line 4356 "ldgram.c"
    break;

  case 315: /* type: INFO  */
#line 1189 "ldgram.y"
                   { sectype = noalloc_section; }
#line 4362 "ldgram.c"
    break;

  case 316: /* type: OVERLAY  */
#line 1190 "ldgram.y"
                   { sectype = noalloc_section; }
#line 4368 "ldgram.c"
    break;

  case 317: /* type: READONLY '(' TYPE '=' exp ')'  */
#line 1191 "ldgram.y"
                                         { sectype = typed_readonly_section; sectype_value = (yyvsp[-1].etree); }
#line 4374 "ldgram.c"
    break;

  case 318: /* type: READONLY  */
#line 1192 "ldgram.y"
                    { sectype = readonly_section; }
#line 4380 "ldgram.c"
    break;

  case 319: /* type: TYPE '=' exp  */
#line 1193 "ldgram.y"
                        { sectype = type_section; sectype_value = (yyvsp[0].etree); }
#line 4386 "ldgram.c"
    break;

  case 321: /* atype: %empty  */
#line 1198 "ldgram.y"
                            { sectype = normal_section; }
#line 4392 "ldgram.c"
    break;

  case 322: /* atype: '(' ')'  */
#line 1199 "ldgram.y"
                        { sectype = normal_section; }
#line 4398 "ldgram.c"
    break;

  case 323: /* opt_exp_with_type: exp atype ':'  */
#line 1203 "ldgram.y"
                                        { (yyval.etree) = (yyvsp[-2].etree); }
#line 4404 "ldgram.c"
    break;

  case 324: /* opt_exp_with_type: atype ':'  */
#line 1204 "ldgram.y"
                                        { (yyval.etree) = (etree_type *)NULL;  }
#line 4410 "ldgram.c"
    break;

  case 325: /* opt_exp_with_type: BIND '(' exp ')' atype ':'  */
#line 1209 "ldgram.y"
                                           { (yyval.etree) = (yyvsp[-3].etree); }
#line 4416 "ldgram.c"
    break;

  case 326: /* opt_exp_with_type: BIND '(' exp ')' BLOCK '(' exp ')' atype ':'  */
#line 1211 "ldgram.y"
                { (yyval.etree) = (yyvsp[-7].etree); }
#line 4422 "ldgram.c"
    break;

  case 327: /* opt_exp_without_type: exp ':'  */
#line 1215 "ldgram.y"
                                { (yyval.etree) = (yyvsp[-1].etree); }
#line 4428 "ldgram.c"
    break;

  case 328: /* opt_exp_without_type: ':'  */
#line 1216 "ldgram.y"
                                { (yyval.etree) = (etree_type *) NULL;  }
#line 4434 "ldgram.c"
    break;

  case 329: /* opt_nocrossrefs: %empty  */
#line 1221 "ldgram.y"
                        { (yyval.integer) = 0; }
#line 4440 "ldgram.c"
    break;

  case 330: /* opt_nocrossrefs: NOCROSSREFS  */
#line 1223 "ldgram.y"
                        { (yyval.integer) = 1; }
#line 4446 "ldgram.c"
    break;

  case 331: /* memspec_opt: '>' NAME  */
#line 1228 "ldgram.y"
                { (yyval.name) = (yyvsp[0].name); }
#line 4452 "ldgram.c"
    break;

  case 332: /* memspec_opt: %empty  */
#line 1229 "ldgram.y"
                { (yyval.name) = DEFAULT_MEMORY_REGION; }
#line 4458 "ldgram.c"
    break;

  case 333: /* phdr_opt: %empty  */
#line 1234 "ldgram.y"
                {
		  (yyval.section_phdr) = NULL;
		}
#line 4466 "ldgram.c"
    break;

  case 334: /* phdr_opt: phdr_opt ':' NAME  */
#line 1238 "ldgram.y"
                {
		  struct lang_output_section_phdr_list *n;

		  n = stat_alloc (sizeof *n);
		  n->name = (yyvsp[0].name);
		  n->used = false;
		  n->next = (yyvsp[-2].section_phdr);
		  (yyval.section_phdr) = n;
		}
#line 4480 "ldgram.c"
    break;

  case 336: /* $@34: %empty  */
#line 1253 "ldgram.y"
                        {
			  ldlex_wild ();
			  lang_enter_overlay_section ((yyvsp[0].name));
			}
#line 4489 "ldgram.c"
    break;

  case 337: /* $@35: %empty  */
#line 1260 "ldgram.y"
                        { ldlex_popstate (); }
#line 4495 "ldgram.c"
    break;

  case 338: /* $@36: %empty  */
#line 1262 "ldgram.y"
                        {
			  if (yychar == NAME)
			    {
			      yyclearin;
			      ldlex_backup ();
			    }
			  lang_leave_overlay_section ((yyvsp[0].fill), (yyvsp[-1].section_phdr));
			}
#line 4508 "ldgram.c"
    break;

  case 343: /* $@37: %empty  */
#line 1283 "ldgram.y"
                     { ldlex_expression (); }
#line 4514 "ldgram.c"
    break;

  case 344: /* $@38: %empty  */
#line 1284 "ldgram.y"
                                            { ldlex_popstate (); }
#line 4520 "ldgram.c"
    break;

  case 345: /* phdr: NAME $@37 phdr_type phdr_qualifiers $@38 ';'  */
#line 1286 "ldgram.y"
                {
		  lang_new_phdr ((yyvsp[-5].name), (yyvsp[-3].etree), (yyvsp[-2].phdr).filehdr, (yyvsp[-2].phdr).phdrs, (yyvsp[-2].phdr).at,
				 (yyvsp[-2].phdr).flags);
		}
#line 4529 "ldgram.c"
    break;

  case 346: /* phdr_type: exp  */
#line 1294 "ldgram.y"
                {
		  (yyval.etree) = (yyvsp[0].etree);

		  if ((yyvsp[0].etree)->type.node_class == etree_name
		      && (yyvsp[0].etree)->type.node_code == NAME)
		    {
		      const char *s;
		      unsigned int i;
		      static const char * const phdr_types[] =
			{
			  "PT_NULL", "PT_LOAD", "PT_DYNAMIC",
			  "PT_INTERP", "PT_NOTE", "PT_SHLIB",
			  "PT_PHDR", "PT_TLS"
			};

		      s = (yyvsp[0].etree)->name.name;
		      for (i = 0;
			   i < sizeof phdr_types / sizeof phdr_types[0];
			   i++)
			if (strcmp (s, phdr_types[i]) == 0)
			  {
			    (yyval.etree) = exp_intop (i);
			    break;
			  }
		      if (i == sizeof phdr_types / sizeof phdr_types[0])
			{
			  if (strcmp (s, "PT_GNU_EH_FRAME") == 0)
			    (yyval.etree) = exp_intop (0x6474e550);
			  else if (strcmp (s, "PT_GNU_STACK") == 0)
			    (yyval.etree) = exp_intop (0x6474e551);
			  else if (strcmp (s, "PT_GNU_RELRO") == 0)
			    (yyval.etree) = exp_intop (0x6474e552);
			  else if (strcmp (s, "PT_GNU_PROPERTY") == 0)
			    (yyval.etree) = exp_intop (0x6474e553);
			  else
			    {
			      einfo (_("\
%X%P:%pS: unknown phdr type `%s' (try integer literal)\n"),
				     NULL, s);
			      (yyval.etree) = exp_intop (0);
			    }
			}
		    }
		}
#line 4578 "ldgram.c"
    break;

  case 347: /* phdr_qualifiers: %empty  */
#line 1342 "ldgram.y"
                {
		  memset (&(yyval.phdr), 0, sizeof (struct phdr_info));
		}
#line 4586 "ldgram.c"
    break;

  case 348: /* phdr_qualifiers: NAME phdr_val phdr_qualifiers  */
#line 1346 "ldgram.y"
                {
		  (yyval.phdr) = (yyvsp[0].phdr);
		  if (strcmp ((yyvsp[-2].name), "FILEHDR") == 0 && (yyvsp[-1].etree) == NULL)
		    (yyval.phdr).filehdr = true;
		  else if (strcmp ((yyvsp[-2].name), "PHDRS") == 0 && (yyvsp[-1].etree) == NULL)
		    (yyval.phdr).phdrs = true;
		  else if (strcmp ((yyvsp[-2].name), "FLAGS") == 0 && (yyvsp[-1].etree) != NULL)
		    (yyval.phdr).flags = (yyvsp[-1].etree);
		  else
		    einfo (_("%X%P:%pS: PHDRS syntax error at `%s'\n"),
			   NULL, (yyvsp[-2].name));
		}
#line 4603 "ldgram.c"
    break;

  case 349: /* phdr_qualifiers: AT '(' exp ')' phdr_qualifiers  */
#line 1359 "ldgram.y"
                {
		  (yyval.phdr) = (yyvsp[0].phdr);
		  (yyval.phdr).at = (yyvsp[-2].etree);
		}
#line 4612 "ldgram.c"
    break;

  case 350: /* phdr_val: %empty  */
#line 1367 "ldgram.y"
                {
		  (yyval.etree) = NULL;
		}
#line 4620 "ldgram.c"
    break;

  case 351: /* phdr_val: '(' exp ')'  */
#line 1371 "ldgram.y"
                {
		  (yyval.etree) = (yyvsp[-1].etree);
		}
#line 4628 "ldgram.c"
    break;

  case 352: /* $@39: %empty  */
#line 1377 "ldgram.y"
                {
		  ldlex_version_file ();
		  PUSH_ERROR (_("dynamic list"));
		}
#line 4637 "ldgram.c"
    break;

  case 353: /* dynamic_list_file: $@39 dynamic_list_nodes  */
#line 1382 "ldgram.y"
                {
		  ldlex_popstate ();
		  POP_ERROR ();
		}
#line 4646 "ldgram.c"
    break;

  case 357: /* dynamic_list_tag: vers_defns ';'  */
#line 1399 "ldgram.y"
                {
		  lang_append_dynamic_list (current_dynamic_list_p, (yyvsp[-1].versyms));
		}
#line 4654 "ldgram.c"
    break;

  case 358: /* $@40: %empty  */
#line 1407 "ldgram.y"
                {
		  ldlex_version_file ();
		  PUSH_ERROR (_("VERSION script"));
		}
#line 4663 "ldgram.c"
    break;

  case 359: /* version_script_file: $@40 vers_nodes  */
#line 1412 "ldgram.y"
                {
		  ldlex_popstate ();
		  POP_ERROR ();
		}
#line 4672 "ldgram.c"
    break;

  case 360: /* $@41: %empty  */
#line 1421 "ldgram.y"
                {
		  ldlex_version_script ();
		}
#line 4680 "ldgram.c"
    break;

  case 361: /* version: $@41 VERSIONK '{' vers_nodes '}'  */
#line 1425 "ldgram.y"
                {
		  ldlex_popstate ();
		}
#line 4688 "ldgram.c"
    break;

  case 364: /* vers_node: '{' vers_tag '}' ';'  */
#line 1437 "ldgram.y"
                {
		  lang_register_vers_node (NULL, (yyvsp[-2].versnode), NULL);
		}
#line 4696 "ldgram.c"
    break;

  case 365: /* vers_node: VERS_TAG '{' vers_tag '}' ';'  */
#line 1441 "ldgram.y"
                {
		  lang_register_vers_node ((yyvsp[-4].name), (yyvsp[-2].versnode), NULL);
		}
#line 4704 "ldgram.c"
    break;

  case 366: /* vers_node: VERS_TAG '{' vers_tag '}' verdep ';'  */
#line 1445 "ldgram.y"
                {
		  lang_register_vers_node ((yyvsp[-5].name), (yyvsp[-3].versnode), (yyvsp[-1].deflist));
		}
#line 4712 "ldgram.c"
    break;

  case 367: /* verdep: VERS_TAG  */
#line 1452 "ldgram.y"
                {
		  (yyval.deflist) = lang_add_vers_depend (NULL, (yyvsp[0].name));
		}
#line 4720 "ldgram.c"
    break;

  case 368: /* verdep: verdep VERS_TAG  */
#line 1456 "ldgram.y"
                {
		  (yyval.deflist) = lang_add_vers_depend ((yyvsp[-1].deflist), (yyvsp[0].name));
		}
#line 4728 "ldgram.c"
    break;

  case 369: /* vers_tag: %empty  */
#line 1463 "ldgram.y"
                {
		  (yyval.versnode) = lang_new_vers_node (NULL, NULL);
		}
#line 4736 "ldgram.c"
    break;

  case 370: /* vers_tag: vers_defns ';'  */
#line 1467 "ldgram.y"
                {
		  (yyval.versnode) = lang_new_vers_node ((yyvsp[-1].versyms), NULL);
		}
#line 4744 "ldgram.c"
    break;

  case 371: /* vers_tag: GLOBAL ':' vers_defns ';'  */
#line 1471 "ldgram.y"
                {
		  (yyval.versnode) = lang_new_vers_node ((yyvsp[-1].versyms), NULL);
		}
#line 4752 "ldgram.c"
    break;

  case 372: /* vers_tag: LOCAL ':' vers_defns ';'  */
#line 1475 "ldgram.y"
                {
		  (yyval.versnode) = lang_new_vers_node (NULL, (yyvsp[-1].versyms));
		}
#line 4760 "ldgram.c"
    break;

  case 373: /* vers_tag: GLOBAL ':' vers_defns ';' LOCAL ':' vers_defns ';'  */
#line 1479 "ldgram.y"
                {
		  (yyval.versnode) = lang_new_vers_node ((yyvsp[-5].versyms), (yyvsp[-1].versyms));
		}
#line 4768 "ldgram.c"
    break;

  case 374: /* vers_defns: VERS_IDENTIFIER  */
#line 1486 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern (NULL, (yyvsp[0].name), ldgram_vers_current_lang, false);
		}
#line 4776 "ldgram.c"
    break;

  case 375: /* vers_defns: NAME  */
#line 1490 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern (NULL, (yyvsp[0].name), ldgram_vers_current_lang, true);
		}
#line 4784 "ldgram.c"
    break;

  case 376: /* vers_defns: vers_defns ';' VERS_IDENTIFIER  */
#line 1494 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern ((yyvsp[-2].versyms), (yyvsp[0].name), ldgram_vers_current_lang, false);
		}
#line 4792 "ldgram.c"
    break;

  case 377: /* vers_defns: vers_defns ';' NAME  */
#line 1498 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern ((yyvsp[-2].versyms), (yyvsp[0].name), ldgram_vers_current_lang, true);
		}
#line 4800 "ldgram.c"
    break;

  case 378: /* @42: %empty  */
#line 1502 "ldgram.y"
                        {
			  (yyval.name) = ldgram_vers_current_lang;
			  ldgram_vers_current_lang = (yyvsp[-1].name);
			}
#line 4809 "ldgram.c"
    break;

  case 379: /* vers_defns: vers_defns ';' EXTERN NAME '{' @42 vers_defns opt_semicolon '}'  */
#line 1507 "ldgram.y"
                        {
			  struct bfd_elf_version_expr *pat;
			  for (pat = (yyvsp[-2].versyms); pat->next != NULL; pat = pat->next);
			  pat->next = (yyvsp[-8].versyms);
			  (yyval.versyms) = (yyvsp[-2].versyms);
			  ldgram_vers_current_lang = (yyvsp[-3].name);
			}
#line 4821 "ldgram.c"
    break;

  case 380: /* @43: %empty  */
#line 1515 "ldgram.y"
                        {
			  (yyval.name) = ldgram_vers_current_lang;
			  ldgram_vers_current_lang = (yyvsp[-1].name);
			}
#line 4830 "ldgram.c"
    break;

  case 381: /* vers_defns: EXTERN NAME '{' @43 vers_defns opt_semicolon '}'  */
#line 1520 "ldgram.y"
                        {
			  (yyval.versyms) = (yyvsp[-2].versyms);
			  ldgram_vers_current_lang = (yyvsp[-3].name);
			}
#line 4839 "ldgram.c"
    break;

  case 382: /* vers_defns: GLOBAL  */
#line 1525 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern (NULL, "global", ldgram_vers_current_lang, false);
		}
#line 4847 "ldgram.c"
    break;

  case 383: /* vers_defns: vers_defns ';' GLOBAL  */
#line 1529 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern ((yyvsp[-2].versyms), "global", ldgram_vers_current_lang, false);
		}
#line 4855 "ldgram.c"
    break;

  case 384: /* vers_defns: LOCAL  */
#line 1533 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern (NULL, "local", ldgram_vers_current_lang, false);
		}
#line 4863 "ldgram.c"
    break;

  case 385: /* vers_defns: vers_defns ';' LOCAL  */
#line 1537 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern ((yyvsp[-2].versyms), "local", ldgram_vers_current_lang, false);
		}
#line 4871 "ldgram.c"
    break;

  case 386: /* vers_defns: EXTERN  */
#line 1541 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern (NULL, "extern", ldgram_vers_current_lang, false);
		}
#line 4879 "ldgram.c"
    break;

  case 387: /* vers_defns: vers_defns ';' EXTERN  */
#line 1545 "ldgram.y"
                {
		  (yyval.versyms) = lang_new_vers_pattern ((yyvsp[-2].versyms), "extern", ldgram_vers_current_lang, false);
		}
#line 4887 "ldgram.c"
    break;

  case 390: /* $@44: %empty  */
#line 1556 "ldgram.y"
                {
		  ldlex_script ();
		  PUSH_ERROR (_("section-ordering-file script"));
		}
#line 4896 "ldgram.c"
    break;

  case 391: /* section_ordering_script_file: $@44 section_ordering_list  */
#line 1561 "ldgram.y"
                {
		  ldlex_popstate ();
		  POP_ERROR ();
		}
#line 4905 "ldgram.c"
    break;

  case 395: /* $@45: %empty  */
#line 1574 "ldgram.y"
                {
		  ldlex_wild ();
		  lang_enter_output_section_statement
		    ((yyvsp[-1].name), NULL, 0, NULL, NULL, NULL, NULL, 0, 0);
		}
#line 4915 "ldgram.c"
    break;

  case 396: /* $@46: %empty  */
#line 1582 "ldgram.y"
                {
		  ldlex_popstate ();
		  lang_leave_output_section_statement (NULL, NULL, NULL, NULL);
		}
#line 4924 "ldgram.c"
    break;


#line 4928 "ldgram.c"

      default: break;
    }
  /* User semantic actions sometimes alter yychar, and that requires
     that yytoken be updated with the new translation.  We take the
     approach of translating immediately before every use of yytoken.
     One alternative is translating here after every semantic action,
     but that translation would be missed if the semantic action invokes
     YYABORT, YYACCEPT, or YYERROR immediately after altering yychar or
     if it invokes YYBACKUP.  In the case of YYABORT or YYACCEPT, an
     incorrect destructor might then be invoked immediately.  In the
     case of YYERROR or YYBACKUP, subsequent parser actions might lead
     to an incorrect destructor call or verbose syntax error message
     before the lookahead is translated.  */
  YY_SYMBOL_PRINT ("-> $$ =", YY_CAST (yysymbol_kind_t, yyr1[yyn]), &yyval, &yyloc);

  YYPOPSTACK (yylen);
  yylen = 0;

  *++yyvsp = yyval;

  /* Now 'shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */
  {
    const int yylhs = yyr1[yyn] - YYNTOKENS;
    const int yyi = yypgoto[yylhs] + *yyssp;
    yystate = (0 <= yyi && yyi <= YYLAST && yycheck[yyi] == *yyssp
               ? yytable[yyi]
               : yydefgoto[yylhs]);
  }

  goto yynewstate;


/*--------------------------------------.
| yyerrlab -- here on detecting error.  |
`--------------------------------------*/
yyerrlab:
  /* Make sure we have latest lookahead translation.  See comments at
     user semantic actions for why this is necessary.  */
  yytoken = yychar == YYEMPTY ? YYSYMBOL_YYEMPTY : YYTRANSLATE (yychar);
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
      yyerror (YY_("syntax error"));
    }

  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse lookahead token after an
         error, discard it.  */

      if (yychar <= YYEOF)
        {
          /* Return failure if at end of input.  */
          if (yychar == YYEOF)
            YYABORT;
        }
      else
        {
          yydestruct ("Error: discarding",
                      yytoken, &yylval);
          yychar = YYEMPTY;
        }
    }

  /* Else will try to reuse lookahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:
  /* Pacify compilers when the user code never invokes YYERROR and the
     label yyerrorlab therefore never appears in user code.  */
  if (0)
    YYERROR;
  ++yynerrs;

  /* Do not reclaim the symbols of the rule whose action triggered
     this YYERROR.  */
  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;      /* Each real token shifted decrements this.  */

  /* Pop stack until we find a state that shifts the error token.  */
  for (;;)
    {
      yyn = yypact[yystate];
      if (!yypact_value_is_default (yyn))
        {
          yyn += YYSYMBOL_YYerror;
          if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYSYMBOL_YYerror)
            {
              yyn = yytable[yyn];
              if (0 < yyn)
                break;
            }
        }

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
        YYABORT;


      yydestruct ("Error: popping",
                  YY_ACCESSING_SYMBOL (yystate), yyvsp);
      YYPOPSTACK (1);
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END


  /* Shift the error token.  */
  YY_SYMBOL_PRINT ("Shifting", YY_ACCESSING_SYMBOL (yyn), yyvsp, yylsp);

  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturnlab;


/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturnlab;


/*-----------------------------------------------------------.
| yyexhaustedlab -- YYNOMEM (memory exhaustion) comes here.  |
`-----------------------------------------------------------*/
yyexhaustedlab:
  yyerror (YY_("memory exhausted"));
  yyresult = 2;
  goto yyreturnlab;


/*----------------------------------------------------------.
| yyreturnlab -- parsing is finished, clean up and return.  |
`----------------------------------------------------------*/
yyreturnlab:
  if (yychar != YYEMPTY)
    {
      /* Make sure we have latest lookahead translation.  See comments at
         user semantic actions for why this is necessary.  */
      yytoken = YYTRANSLATE (yychar);
      yydestruct ("Cleanup: discarding lookahead",
                  yytoken, &yylval);
    }
  /* Do not reclaim the symbols of the rule whose action triggered
     this YYABORT or YYACCEPT.  */
  YYPOPSTACK (yylen);
  YY_STACK_PRINT (yyss, yyssp);
  while (yyssp != yyss)
    {
      yydestruct ("Cleanup: popping",
                  YY_ACCESSING_SYMBOL (+*yyssp), yyvsp);
      YYPOPSTACK (1);
    }
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif

  return yyresult;
}

#line 1588 "ldgram.y"

static void
yyerror (const char *arg)
{
  if (ldfile_assumed_script)
    einfo (_("%P:%s: file format not recognized; treating as linker script\n"),
	   ldlex_filename ());
  if (error_index > 0 && error_index < ERROR_NAME_MAX)
    fatal (_("%P:%pS: %s in %s\n"), NULL, arg, error_names[error_index - 1]);
  else
    fatal ("%P:%pS: %s\n", NULL, arg);
}
