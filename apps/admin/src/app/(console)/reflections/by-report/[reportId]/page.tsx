import { notFound, redirect } from 'next/navigation';
import { Empty } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import { isUuid } from '@/lib/reflections';

/** From a report about a reflection to the reflection's review page (contract §4 `GET …/by-report/:reportId`). */
export default async function ReflectionByReport({ params }: { params: Promise<{ reportId: string }> }) {
  const { reportId } = await params;
  if (!isUuid(reportId)) notFound();
  const found = await load<{ reflectionId: string }>(`/admin/reflections/by-report/${encodeURIComponent(reportId)}`);
  if (isForbidden(found)) return <Empty>Your role cannot open reflections.</Empty>;
  if (!isUuid(found.reflectionId)) notFound();
  redirect(`/reflections/${found.reflectionId}`);
}
