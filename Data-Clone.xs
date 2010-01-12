#define PERL_NO_GET_CONTEXT
#define NO_XSLOCKS /* for exceptions */
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#include "data_clone.h"

#ifndef get_cvs
#define get_cvs(s, flags) get_cv((s), (flags))
#endif

#define REINTERPRET_CAST(T, value) ((T)value)

#define PTR2STR(ptr) REINTERPRET_CAST(const char*, (&ptr))

#define MY_CXT_KEY "Data::Clone::_guts" XS_VERSION
typedef struct {
    U32 depth;
    HV* seen;
    HV* lock;
    GV* my_clone;
} my_cxt_t;
START_MY_CXT

static SV*
clone_rv(pTHX_ pMY_CXT_ SV* const cloning);

static SV*
clone_sv(pTHX_ pMY_CXT_ SV* const cloning) {
    assert(cloning);

    SvGETMAGIC(cloning);

    if(SvROK(cloning)){
        return clone_rv(aTHX_ aMY_CXT_ cloning);
    }
    else{
        SV* const cloned = newSV(0);
        /* no need to set SV_GMAGIC */
        sv_setsv_flags(cloned, cloning, SV_NOSTEAL);
        return cloned;
    }
}

static void
clone_hv_to(pTHX_ pMY_CXT_ HV* const cloning, HV* const cloned) {
    HE* iter;

    assert(cloning);
    assert(cloning);

    hv_iterinit(cloning);
    while((iter = hv_iternext(cloning))){
        SV* const key = hv_iterkeysv(iter);
        SV* const val = clone_sv(aTHX_ aMY_CXT_ hv_iterval(cloning, iter));
        (void)hv_store_ent(cloned, key, val, 0U);
    }
}

static void
clone_av_to(pTHX_ pMY_CXT_ AV* const cloning, AV* const cloned) {
    I32 last, i;

    assert(cloning);
    assert(cloned);

    last = av_len(cloning);
    av_extend(cloned, last);

    for(i = 0; i <= last; i++){
        SV** const svp = av_fetch(cloning, i, FALSE);
        if(svp){
            (void)av_store(cloned, i, clone_sv(aTHX_ aMY_CXT_ *svp));
        }
    }
}


static GV*
find_method_pvn(pTHX_ HV* const stash, const char* const name, I32 const namelen) {
    GV** const gvp = (GV**)hv_fetch(stash, name, namelen, FALSE);
    if(gvp && isGV(*gvp) && GvCV(*gvp)){ /* shortcut */
        return *gvp;
    }

    return gv_fetchmeth_autoload(stash, name, namelen, 0);
}

static int
sv_has_backrefs(pTHX_ SV* const sv) {
    if(SvRMAGICAL(sv) && mg_find(sv, PERL_MAGIC_backref)) {
        return TRUE;
    }
#ifdef HvAUX
    else if(SvTYPE(sv) == SVt_PVHV){
        return SvOOK(sv) && HvAUX((HV*)sv)->xhv_backreferences != NULL;
    }
#endif
    return FALSE;
}

static void
store_to_seen(pTHX_ pMY_CXT_ SV* const sv, SV* const proto) {
    (void)hv_store(MY_CXT.seen, PTR2STR(sv), sizeof(sv), proto, 0U);
    SvREFCNT_inc_simple_void_NN(proto);
}

static SV*
clone_rv(pTHX_ pMY_CXT_ SV* const cloning) {
    int may_be_circular;
    SV*  sv;
    SV*  proto;
    SV*  cloned;

    assert(cloning);
    assert(SvROK(cloning));

    sv = SvRV(cloning);
    may_be_circular = (SvREFCNT(sv) > 1 || sv_has_backrefs(aTHX_ sv) );

    if(may_be_circular){
        SV** const svp = hv_fetch(MY_CXT.seen, PTR2STR(sv), sizeof(sv), FALSE);
        if(svp){
            proto = *svp;
            goto finish;
        }
    }

    if(SvOBJECT(sv)){
        GV* const method = find_method_pvn(aTHX_ SvSTASH(sv), STR_WITH_LEN("clone"));

        if(!method){ /* not a clonable object */
            proto = sv;
            goto finish;
        }

        /* has its own clone method */
        if(GvCV(method) != GvCV(MY_CXT.my_clone)
            && !hv_exists(MY_CXT.lock, PTR2STR(sv), sizeof(sv))){
            dSP;

            ENTER;
            SAVETMPS;

            /* lock the referent to avoid recursion */
            SAVEDELETE(MY_CXT.lock, savepvn(PTR2STR(sv), sizeof(sv)), sizeof(sv));
            (void)hv_store(MY_CXT.lock, PTR2STR(sv), sizeof(sv), &PL_sv_undef, 0U);

            PUSHMARK(SP);
            XPUSHs(cloning);
            PUTBACK;

            call_sv((SV*)method, G_SCALAR);

            SPAGAIN;
            cloned = POPs;
            PUTBACK;

            SvREFCNT_inc_simple_void_NN(cloned);

            FREETMPS;
            LEAVE;
            return cloned;
        }
        /* fall through to the default cloneing routine */
    }

    if(SvTYPE(sv) == SVt_PVAV){
        proto = sv_2mortal((SV*)newAV());
        if(may_be_circular){
            store_to_seen(aTHX_ aMY_CXT_ sv, proto);
        }
        clone_av_to(aTHX_ aMY_CXT_ (AV*)sv, (AV*)proto);
    }
    else if(SvTYPE(sv) == SVt_PVHV){
        proto = sv_2mortal((SV*)newHV());
        if(may_be_circular){
            store_to_seen(aTHX_ aMY_CXT_ sv, proto);
        }
        clone_hv_to(aTHX_ aMY_CXT_ (HV*)sv, (HV*)proto);
    }
    else {
        proto = sv; /* do nothing */
    }

    finish:
    cloned = newRV_inc(proto);

    if(SvOBJECT(sv)){
        sv_bless(cloned, SvSTASH(sv));
    }

    return SvWEAKREF(cloning) ? sv_rvweaken(cloned) : cloned;
}

/* as SV* sv_clone(SV* sv) */
SV*
Data_Clone_sv_clone(pTHX_ SV* const sv) {
    SV* VOL retval = NULL;
    dMY_CXT;
    dXCPT;

    if(++MY_CXT.depth == U32_MAX){
        Perl_croak(aTHX_ "Depth overflow on clone()");
    }

    XCPT_TRY_START {
        retval = sv_2mortal(clone_sv(aTHX_ aMY_CXT_ sv));
    } XCPT_TRY_END

    if(--MY_CXT.depth == 0){
        hv_undef(MY_CXT.seen);
        hv_undef(MY_CXT.lock);
    }

    XCPT_CATCH {
        XCPT_RETHROW;
    }
    return retval;
}

static void
my_cxt_initialize(pTHX_ pMY_CXT) {
    MY_CXT.depth    = 0;
    MY_CXT.seen     = newHV();
    MY_CXT.lock     = newHV();
    MY_CXT.my_clone = CvGV(get_cvs("Data::Clone::clone", GV_ADD));
}

MODULE = Data::Clone	PACKAGE = Data::Clone

PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    my_cxt_initialize(aTHX_ aMY_CXT);
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    my_cxt_initialize(aTHX_ aMY_CXT);
    PERL_UNUSED_VAR(items);
}

#endif

void
clone(SV* sv)
CODE:
{
    ST(0) = sv_clone(sv);
    XSRETURN(1);
}

void
data_clone(SV* sv)
CODE:
{
    ST(0) = sv_clone(sv);
    XSRETURN(1);
}
