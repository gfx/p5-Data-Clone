#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#include "xs_assert.h"

#define REINTERPRET_CAST(T, value) ((T)value)

#define MY_CXT_KEY "Data::Clone::_guts" XS_VERSION
typedef struct {
    GV* my_clone;
} my_cxt_t;
START_MY_CXT

static SV*
rv_clone(pTHX_ SV* const cloning, HV* const seen);

static SV*
sv_clone_to(pTHX_ SV* const cloning, SV* const cloned, HV* const seen) {
    assert_not_null(cloning);
    assert_not_null(cloned);
    assert(cloning != cloned);

    SvGETMAGIC(cloning);

    if(SvROK(cloning)){
        SV* const sv = rv_clone(aTHX_ cloning, seen);
        sv_setsv_flags(cloned, sv, SV_NOSTEAL);
        SvREFCNT_dec(sv);
    }
    else{
        /* no need to set SV_GMAGIC */
        sv_setsv_flags(cloned, cloning, SV_NOSTEAL);
    }
    return cloned;
}

static SV*
sv_clone(pTHX_ SV* const cloning, HV* const seen) {
    assert_not_null(cloning);
    assert_sv_is_hv((SV*)seen);

    return sv_clone_to(aTHX_ cloning, newSV(0), seen);
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
        SV** const svp = hv_fetch(seen, REINTERPRET_CAST(const char*, sv), sizeof(sv), FALSE);
        if(svp){
            proto = *svp;
            goto finish;
        }
    }

    if(SvOBJECT(sv)){
        dMY_CXT;
        GV* const method = find_method_pvn(aTHX_ SvSTASH(sv), STR_WITH_LEN("clone"));
        if(!method){ /* no clonable */
            proto = sv;
            goto finish;
        }

        /* has custom clone() method */
        if(GvCV(method) != GvCV(MY_CXT.my_clone)){
            CV* entity;
            dSP;

            ENTER;
            SAVETMPS;

            /* temporary *clone = \&Data::Clone::clone to prevent clone() from
               recursive calls */

            entity = GvCV(method);
            SAVESPTR(GvCV(method));
            GvCV(method) = GvCV(MY_CXT.my_clone);

            PUSHMARK(SP);
            XPUSHs(cloning);
            PUTBACK;

            call_sv((SV*)entity, G_SCALAR);

            SPAGAIN;
            cloned = POPs;
            PUTBACK;

            SvREFCNT_inc_simple_void_NN(cloned);

            FREETMPS;
            LEAVE;
            return cloned;
        }
        /* default clone() */
    }

    if(SvTYPE(sv) == SVt_PVAV){
        proto = (SV*)newAV();
        if(may_be_circular){
            (void)hv_store(seen, REINTERPRET_CAST(const char*, sv), sizeof(sv), proto, 0U);
        }
        av_clone_to(aTHX_ (AV*)sv, (AV*)proto, seen);
    }
    else if(SvTYPE(sv) == SVt_PVHV){
        proto = (SV*)newHV();
        if(may_be_circular){
            (void)hv_store(seen, REINTERPRET_CAST(const char*, sv), sizeof(sv), proto, 0U);
        }
        hv_clone_to(aTHX_ (HV*)sv, (HV*)proto, seen);
    }
    else {
        proto = sv; /* do nothing */
        SvREFCNT_inc_simple_void_NN(proto);
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
    MY_CXT.my_clone = CvGV(get_cv("Data::Clone::clone", GV_ADD));
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    MY_CXT.my_clone = CvGV(get_cv("Data::Clone::clone", GV_ADD));
    PERL_UNUSED_VAR(items);
}

#endif

void
clone(SV* sv)
CODE:
{
    dXSTARG;
    HV* const seen = newHV();
    sv_2mortal((SV*)seen);

    ST(0) = sv_clone_to(aTHX_ sv, TARG, seen);
    XSRETURN(1);
    PERL_UNUSED_VAR(ix);
}
ALIAS:
    clone      = 0
    data_clone = 1
