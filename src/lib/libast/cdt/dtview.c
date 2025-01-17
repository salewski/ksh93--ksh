/***********************************************************************
*                                                                      *
*               This software is part of the ast package               *
*          Copyright (c) 1985-2011 AT&T Intellectual Property          *
*          Copyright (c) 2020-2024 Contributors to ksh 93u+m           *
*                      and is licensed under the                       *
*                 Eclipse Public License, Version 2.0                  *
*                                                                      *
*                A copy of the License is available at                 *
*      https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.html      *
*         (with md5 checksum 84283fa8859daf213bdda5a9f8d1be1d)         *
*                                                                      *
*                 Glenn Fowler <gsf@research.att.com>                  *
*                  David Korn <dgk@research.att.com>                   *
*                   Phong Vo <kpv@research.att.com>                    *
*                  Martijn Dekker <martijn@inlv.org>                   *
*                                                                      *
***********************************************************************/
#include	"dthdr.h"

/*	Set a view path from dict to view.
**
**	Written by Kiem-Phong Vo (5/25/96)
*/

/* these operations must be done without viewpathing */
#define DT_NOVIEWPATH	(DT_INSERT|DT_APPEND|DT_DELETE|\
			 DT_ATTACH|DT_DETACH|DT_RELINK|DT_CLEAR| \
			 DT_FLATTEN|DT_EXTRACT|DT_RESTORE|DT_STAT)

static void* dtvsearch(Dt_t* dt, void* obj, int type)
{
	int		cmp;
	Dt_t		*d, *p;
	void		*o, *n, *oky, *nky;

	if(type&DT_NOVIEWPATH)
		return (*(dt->meth->searchf))(dt,obj,type);

	o = NULL;

	/* these ops look for the first appearance of an object of the right type */
	if((type & (DT_MATCH|DT_SEARCH)) ||
	   ((type & (DT_FIRST|DT_LAST|DT_ATLEAST|DT_ATMOST)) && !(dt->meth->type&DT_ORDERED) ) )
	{	for(d = dt; d; d = d->view)
			if((o = (*(d->meth->searchf))(d,obj,type)) )
				break;
		dt->walk = d;
		return o;
	}

	if(dt->meth->type & DT_ORDERED) /* ordered sets/bags */
	{	if(!(type & (DT_FIRST|DT_LAST|DT_NEXT|DT_PREV|DT_ATLEAST|DT_ATMOST)) )
			return NULL;

		/* find the min/max element that satisfies the op requirement */
		n = nky = NULL; p = NULL;
		for(d = dt; d; d = d->view)
		{	if(!(o = (*d->meth->searchf)(d, obj, type)) )
				continue;
			oky = _DTKEY(d->disc,o);

			if(n) /* get the right one among all dictionaries */
			{	cmp = _DTCMP(d,oky,nky,d->disc);
				if(((type & (DT_NEXT|DT_FIRST|DT_ATLEAST)) && cmp < 0) ||
				   ((type & (DT_PREV|DT_LAST|DT_ATMOST)) && cmp > 0) )
					goto b_est;
			}
			else
			{ b_est: /* current best element to fit op requirement */
				p  = d;
				n  = o;
				nky = oky;
			}
		}

		dt->walk = p;
		return n;
	}

	/* unordered collections */
	if(!(type&(DT_NEXT|DT_PREV)) )
		return NULL;

	if(!dt->walk )
	{	for(d = dt; d; d = d->view)
			if((o = (*(d->meth->searchf))(d, obj, DT_SEARCH)) )
				break;
		dt->walk = d;
		if(!(obj = o) )
			return NULL;
	}

	for(d = dt->walk, obj = (*d->meth->searchf)(d, obj, type);; )
	{	while(obj) /* keep moving until finding an uncovered object */
		{	for(p = dt; ; p = p->view)
			{	if(p == d) /* adjacent object is uncovered */
					return obj;
				if((*(p->meth->searchf))(p, obj, DT_SEARCH) )
					break;
			}
			obj = (*d->meth->searchf)(d, obj, type);
		}

		if(!(d = dt->walk = d->view) ) /* move on to next dictionary */
			return NULL;
		else if(type&DT_NEXT)
			obj = (*(d->meth->searchf))(d,NULL,DT_FIRST);
		else	obj = (*(d->meth->searchf))(d,NULL,DT_LAST);
	}
}

Dt_t* dtview(Dt_t* dt, Dt_t* view)
{
	Dt_t*	d;

	if(view && view->meth != dt->meth) /* must use the same method */
		return NULL;

	/* make sure there won't be a cycle */
	for(d = view; d; d = d->view)
		if(d == dt)
			return NULL;

	/* no more viewing lower dictionary */
	if((d = dt->view) )
		d->nview -= 1;
	dt->view = dt->walk = NULL;

	if(!view)
	{	dt->searchf = dt->meth->searchf;
		return d;
	}

	/* ok */
	dt->view = view;
	dt->searchf = dtvsearch;
	view->nview += 1;

	return view;
}
