#define PERL_NO_GET_CONTEXT
#define NO_XSLOCKS /* for exceptions */
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#include "xs_assert.h"

#define REINTERPRET_CAST(T, value) ((T)value)

#define PTR2STR(ptr) REINTERPRET_CAST(const char*, (ptr))

#define MY_CXT_KEY "Data::Clone::_guts" XS_VERSION
typedef struct {
    I32 depth;
    HV* seen;
    HV* lock;
    GV* my_clone;
} my_cxt_t;
START_MY_CXT

static SV*
rv_clone(pTHX_ SV* const cloning, HV* const seen);

static SV*
sv_clone(pTHX_ SV* const cloning, HV* const seen) {
    SV* cloned;

    assert_not_null(cloning);
    assert_sv_is_hv((SV*)seen);

    SvGETMAGIC(cloning);

    if(SvROK(cloning)){
        cloned = rv_clone(aTHX_ cloning, seen);
    }
    else{
        cloned = newSV(0);
        /* no need to set SV_GMAGIC */
        sv_setsv_flags(cloned, cloning, SV_NOSTEAL);
    }
    return cloned;
}

static void
hv_clone_to(pTHX_ HV* const cloning, HV* const cloned, HV* const seen) {
    HE* iter;

    assert_sv_is_hv((SV*)cloning);
    assert_sv_is_hv((SV*)cloned);

    hv_iterinit(cloning);
    while((iter = hv_iternext(cloning))){
        SV* const sv = sv_clone(aTHX_ hv_iterval(cloning, iter), seen);
        (void)hv_store_ent(cloned, hv_iterkeysv(iter), sv, 0U);
    }
}

static void
av_clone_to(pTHX_ AV* const cloning, AV* const cloned, HV* const seen) {
    I32 last, i;

    assert_sv_is_av((SV*)cloning);
    assert_sv_is_av((SV*)cloned);

    last = av_len(cloning);
    av_extend(cloned, last);

    for(i = 0; i <= last; i++){
        SV** const svp = av_fetch(cloning, i, FALSE);
        if(svp){
            (void)av_store(cloned, i, sv_clone(aTHX_ *svp, seen));
        }
    }
}


static GV*
find_method_pvn(pTHX_ HV* const stash, const char* const name, I32 const namelen){
    GV** const gvp = (GV**)hv_fetch(stash, name, namelen, FALSE);
    if(gvp && isGV(*gvp) && GvCV(*gvp)){ /* shortcut */
        return *gvp;
    }

    return gv_fetchmeth_autoload(stash, name, namelen, 0);
}

static SV*
rv_clone(pTHX_ SV* const cloning, HV* const seen) {
    int may_be_circular;
    SV*  sv;
    SV*  proto;
    SV*  cloned;

    assert_sv_rok(cloning);
    assert_sv_is_hv((SV*)seen);

    sv = SvRV(cloning);
    may_be_circular = (SvREFCNT(sv) > 1);

    if(may_be_circular){
        SV** const svp = hv_fetch(seen, PTR2STR(sv), sizeof(sv), FALSE);
        if(svp){
            proto = *svp;
            goto finish;
        }
    }

    if(SvOBJECT(sv)){
        dMY_CXT;
        GV* const method = find_method_pvn(aTHX_ SvSTASH(sv), STR_WITH_LEN("clone"));

        if(!method){ /* not a clonable object */
            proto = sv;
            goto finish;
        }

        /* has custom clone() method */
        if(GvCV(method) != GvCV(MY_CXT.my_clone)
            && !hv_exists(MY_CXT.lock, PTR2STR(sv), sizeof(sv))){
            dSP;

            ENTER;
            SAVETMPS;

            /* lock the referent to avoid recursion */
            hv_store(MY_CXT.lock, PTR2STR(sv), sizeof(sv), &PL_sv_undef, 0U);

            PUSHMARK(SP);
            XPUSHs(cloning);
            PUTBACK;

            call_sv((SV*)method, G_SCALAR);

            SPAGAIN;
            cloned = POPs;
            PUTBACK;

            SvREFCNT_inc_simple_void_NN(cloned);

            /* unlock the referent */
            hv_delete(MY_CXT.lock, PTR2STR(sv), sizeof(sv), G_DISCARD);

            FREETMPS;
            LEAVE;
            return cloned;
        }
        /* default clone() */
    }

    if(SvTYPE(sv) == SVt_PVAV){
        proto = sv_2mortal((SV*)newAV());
        if(may_be_circular){
            (void)hv_store(seen, PTR2STR(sv), sizeof(sv), proto, 0U);
            SvREFCNT_inc_simple_void_NN(proto);
        }
        av_clone_to(aTHX_ (AV*)sv, (AV*)proto, seen);
    }
    else if(SvTYPE(sv) == SVt_PVHV){
        proto = sv_2mortal((SV*)newHV());
        if(may_be_circular){
            (void)hv_store(seen, PTR2STR(sv), sizeof(sv), proto, 0U);
            SvREFCNT_inc_simple_void_NN(proto);
        }
        hv_clone_to(aTHX_ (HV*)sv, (HV*)proto, seen);
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

MODULE = Data::Clone	PACKAGE = Data::Clone

PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    MY_CXT.depth    = 0;
    MY_CXT.seen     = newHV();
    MY_CXT.lock     = newHV();
    MY_CXT.my_clone = CvGV(get_cv("Data::Clone::clone", GV_ADD));
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    MY_CXT.depth    = 0;
    MY_CXT.seen     = newHV();
    MY_CXT.lock     = newHV();
    MY_CXT.my_clone = CvGV(get_cv("Data::Clone::clone", GV_ADD));
    PERL_UNUSED_VAR(items);
}

#endif

void
clone(SV* sv)
CODE:
{
    dMY_CXT;
    dXCPT;

    MY_CXT.depth++;
    if(MY_CXT.depth > 255){
        if(ckWARN(WARN_RECURSION)){
            Perl_warner(aTHX_ packWARN(WARN_RECURSION),
                "Deep recursion on clone()");
        }
    }
    else if(MY_CXT.depth < 0) {
        Perl_croak(aTHX_ "Depth overflow on clone()");
    }

    XCPT_TRY_START {
        ST(0) = sv_2mortal(sv_clone(aTHX_ sv, MY_CXT.seen));
    } XCPT_TRY_END

    if(--MY_CXT.depth == 0){
        hv_undef(MY_CXT.seen);
        hv_undef(MY_CXT.lock);
    }

    XCPT_CATCH {
        XCPT_RETHROW;
    }

    XSRETURN(1);
    PERL_UNUSED_VAR(ix);
}
ALIAS:
    clone      = 0
    data_clone = 1
